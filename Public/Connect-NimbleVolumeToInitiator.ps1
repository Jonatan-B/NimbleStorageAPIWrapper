function Connect-NimbleVolumeToInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        # Name of the Initiator where the Volume will be connected to
        [Parameter(Mandatory, Position=0)]
        [String]
        $ComputerName,
        # Id of the Volume that will be connected to the Initiator.
        [Parameter(Mandatory, Position=1)]
        [String]
        $VolumeName,
        # Name of the Array where the Volume is online.
        [Parameter(Mandatory, Position=2)]
        [String]
        $ArrayUrl
    )
    begin {
        if($Global:NimbleSession."Session__$ArrayUrl"){
            if(($Global:NimbleSession."Session__$ArrayUrl".IsConnected -eq $false) -or ($Global:NimbleSession."Session__$ArrayUrl".IsTokenExpired() -eq $true)){

                throw "A session to $($ArrayUrl) already existed but is not longer connected, or has expired. Please create a new session."
            }
        }
        else {
            throw "Unable to query the nimble without a token session."
        }

        Write-Verbose -Message "Nimble session to $ArrayUrl is connected and not expired. Continuing."

        $VolumeInformation = Get-NimbleVolume -ListWithDetails -ArrayUrl $ArrayUrl | Where-Object Name -eq $VolumeName
        
        $DiscoveryNetworkIPs = Get-NimbleNetworkAdapter -ListWithDetails -ArrayUrl $ArrayUrl -AdapterRole Active | Select-Object -ExpandProperty subnet_list | Where-Object type -eq "data"
        $IscsiTargetPortalPort = 3260
        
        $HostAddress_iScsiInterfaces = Invoke-Command -ComputerName $ComputerName -Command {Get-NetIpAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object InterfaceAlias -match "iscsi-[a-b]" }
        if(!($HostAddress_iScsiInterfaces)){
            throw "The machine $($computerName) does not have iscsi interfaces, or they are not properly labeled."
        }
    }
    Process {

        if(!($VolumeInformation)){
            Write-Error -Message "Unable to find the volume $($VolumeName) on array $($ArrayUrl)."
            return
        }

        if($VolumeInformation.owned_by_group -ne $ArrayUrl){
            Write-Error -Message "The volume $($VolumeName) does not belong to this array. Initiators may not connect to it."
            return
        }

        if($PSCmdlet.ShouldProcess($ComputerName, "Attach volume $($VolumeName).")) {
            

            Write-Verbose -Message "Check if the iScsi drive is already connected."
            $IsConnected = (invoke-command -ComputerName $ComputerName -Command { Get-IscsiSession | Where-Object TargetNodeAddress -eq $using:VolumeInformation.target_name }  ) -eq $null
            if(!($IsConnected)){
                Write-Verbose -Message "The machine $($ComputerName) already has the attached volume."
                return
            }
            
            foreach($DiscoveryNetworkIP in $DiscoveryNetworkIPs){
                Write-Verbose -Message "Check that the array has been added to the discovery."
                
            }

            Write-Verbose -Message "Creating the Nimble iScsi connection to the server."
            foreach($NetworkInterface in $HostAddress_iScsiInterfaces){
                if($NetworkInterface.InterfaceAlias -match "iscsi-[a-b]"){
                    
                    $NimbleDiscoveryIP = $DiscoveryNetworkIPs | Where-Object Label -match $Matches.0 | Select-Object -ExpandProperty discovery_ip
                    Write-Verbose -Message "The $($ArrayUrl) discovery IP is: $($NimbleDiscoveryIP)"

                    Write-Verbose -Message "Checking that the discovery IP exists as a TargetPortal on the server."
                    $iScsiDiscoveryTargetPortal = Get-IscsiTargetPortal -CimSession $ComputerName | Where-Object { $_.TargetPortalAddress -eq $NimbleDiscoveryIP }
                    if(!($iScsiDiscoveryTargetPortal)){
                        Write-Warning -Message "The machine $($ComputerName) does not have the array $($ArrayUrl) in its discovery settings."
                        Write-verbose -Message "Adding the target."
                        try {
                            $iScsiDiscoveryTargetPortal = New-IscsiTargetPortal -TargetPortalAddress $NimbleDiscoveryIP -TargetPortalPortNumber $IscsiTargetPortalPort -InitiatorPortalAddress $NetworkInterface.IpAddress -CimSession $ComputerName -ErrorAction Stop
                        }
                        catch {
                            throw "The discovery ip $($NimbleDiscoveryIP) for $($ArrayUrl) is not found, and failed to be created."
                        }
                        
                    }

                    try {
                        Write-Verbose -Message "Getting the iscsi target $($VolumeInformation.target_name) on $($ComputerName) before attempting to connect it."
                        Get-IscsiTarget -NodeAddress $VolumeInformation.target_name -CimSession $ComputerName -ErrorAction Stop  | Out-Null
                    }
                    catch {
                        Write-Verbose -Message "Targets volume was not found on $($ComputerName) updating the list before trying again."
                        Invoke-Command -ComputerName $ComputerName -Command {
                            param($IPAddress)
                            "Getting the Target Portal with address $($IpAddress)."
                            Get-IscsiTargetPortal | Where-Object { $_.TargetPortalAddress -eq $IPAddress }
                            $TargetPortal = Get-IscsiTargetPortal | Where-Object { $_.TargetPortalAddress -eq $IPAddress }
                            if($TargetPortal){
                                "Executing update iscsi target."
                                Update-IscsiTarget -IscsiTargetPortal $TargetPortal
                            }
                            else {
                                "Target Portal not found."
                            }
                            
                        } -ArgumentList $NimbleDiscoveryIP
                        
                        
                        Get-IscsiTarget -NodeAddress $VolumeInformation.target_name -CimSession $ComputerName -ErrorAction Stop | Out-Null
                    }

                    
                    Write-Verbose -Message "The target was found, and will be connected."

                    $ConnectIscsiParameters = @{
                        NodeAddress = $VolumeInformation.target_name 
                        TargetPortalAddress = $NimbleDiscoveryIP 
                        TargetPortalPortNumber = $IscsiTargetPortalPort 
                        InitiatorPortalAddress = $NetworkInterface.IpAddress 
                        IsPersistent = $true 
                        IsMultipathEnabled = $true 
                        CimSession = $ComputerName
                    }
                    $ConnectIscsiParameters.Keys | ForEach-Object { Write-Verbose -Message "$($_) = $($ConnectIscsiParameters.$_)"}
                    Write-Verbose -Message ""

                    $NewIscsiSession = Connect-IscsiTarget @ConnectIscsiParameters -ErrorAction Stop
                }
            }
            if($NewIscsiSession){
                Write-Verbose -Message "Getting the disk and setting it online."
                
                try{
                    $NewIscsiSession | Get-Disk -CimSession $ComputerName | ForEach-Object { Set-Disk $_.Number -CimSession $ComputerName -IsOffline $false -ErrorAction Stop }
                }
                catch {
                    if($_.Exception -match "Microsoft Failover Clustering") {
                        Invoke-Command -ComputerName $ComputerName -Command { 
                            Import-Module FailoverClusters; 
                            $resource = Get-ClusterSharedVolume -Name $using:VolumeName
                            if($resource.State -ne "Online"){
                                try {
                                    $resource | Start-ClusterResource -ErrorAction Stop
                                }
                                catch {
                                    Write-Warning -Message "Failed to do anyhting with the Cluster Resource. Make sure its fine."
                                }
                                
                            }
                            else {
                                Write-Verbose -Message "The volume $($using:VolumeName) is a cluster drive and is already online."
                            }
                        }
                    }
                    else {
                        Write-Error -Message $_.Exception
                    }
                }
            }            
        }
    }
}