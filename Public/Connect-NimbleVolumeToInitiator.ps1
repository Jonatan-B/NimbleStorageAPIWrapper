function Connect-NimbleVolumeToInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        # Name of the Initiator where the Volume will be connected to
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({ Test-NetConnection -ComputerName $_ -Port 5985 -InformationLevel Quiet })]
        [String[]]
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
    }
    Process {

        foreach($Computer in $ComputerName){
            Write-Verbose -Message "Attempting to connect volume $($VolumeName) to initiator $($Computer)."
            
            Write-Verbose -Message "Ensuring that that the volume exists."
            $VolumeInformation = Get-NimbleVolume -ListWithDetails -ArrayUrl $ArrayUrl | Where-Object Name -eq $VolumeName
            if(!($VolumeInformation)){
                Write-Error -Message "Unable to find the volume $($VolumeName) on array $($ArrayUrl)." -ErrorAction Stop
            }
    
            Write-Verbose -Message "Ensuring that that the volume is online."
            if(!($VolumeInformation.online)) {
                Write-Error -Message "The volume is not online, and cannot be connected to the initiator." -ErrorAction Stop
            }
            
            Write-Verbose -Message "Ensuring that that the volume is owned by the array.."
            if($ArrayUrl -notmatch $VolumeInformation.owned_by_group){
                Write-Error -Message "The volume $($VolumeName) does not owned by $($ArrayUrl). Initiators may not connect to it." -ErrorAction Stop
            }
            
            Write-Verbose -Message "Getting the IP addresses that will be used for iSCSI connections from $($Computer)."
            $HostAddress_iScsiInterfaces = Get-NetIpAddress -AddressFamily IPv4 -CimSession $Computer -ErrorAction Stop | Where-Object { $_.IPAddress -match "^192\W168\W((6)|(20))\W\d?\d?\d?$" }
            if(!($HostAddress_iScsiInterfaces)){
                throw "The machine $($Computer) does not have iscsi interfaces, or they are not properly configured."
            }    
    
            Write-Verbose -Message "Getting the data IP addresses from the array."
            $ArrayDataNetworks = Get-NimbleNetworkAdapter -ListWithDetails -ArrayUrl $ArrayUrl -AdapterRole Active -ErrorAction Stop | Select-Object -ExpandProperty subnet_list | Where-Object type -eq "data"
            if(!($ArrayDataNetworks)){
                throw "The API call did not return an error, but also did not return any data. Check the array and ensure that the correct subnets are configured as data."
            }

            $IscsiTargetPortalPort = 3260
    
            Write-Verbose -Message "Check that $($Computer) has the array added to its target portals."
            $iSCSITargetPortals = Get-IscsiTargetPortal -TargetPortalAddress $ArrayDataNetworks.discovery_ip -TargetPortalPortNumber $IscsiTargetPortalPort -CimSession $Computer -ErrorAction SilentlyContinue
            if(!($iSCSITargetPortals)){
                Write-Warning -Message "No target portals were found in $($Computer) with IP addresses $($ArrayDataNetworks.discovery_ip -join ", ")"

                if($ConfirmPreference -ne "None"){
                    $ConfirmPreference = "High"
                }

                if($PSCmdlet.ShouldContinue("The array data IPs were not found as target portals on $($Computer), should they be added?","Add Discovery IPs as Target Portals on $($Computer)")){
                    $ConfirmPreference = "Low"
                    foreach($Interface in $ArrayDataNetworks){
                        if($PSCmdlet.ShouldProcess($Computer, "Create TargetPortal with Ip $($Interface.discovery_ip):$($IscsiTargetPortalPort).")){
                            try {
                                Write-Verbose -Message "Attempting to add the target portal $($Interface.discovery_ip):$($IscsiTargetPortalPort) to $($Computer)."
                                New-IscsiTargetPortal -TargetPortalAddress $Interface.discovery_ip -TargetPortalPortNumber $IscsiTargetPortalPort -CimSession $Computer -ErrorAction Stop
                                Write-Verbose -Message "Target Portal $($Interface.discovery_ip):$($IscsiTargetPortalPort) successfully added to $($Computer)."
                            }
                            catch {
                                Write-Error -Message "Failed to add a target portal with ip $($Interface.discovery_ip):$($IscsiTargetPortalPort) to $($Computer). Error: $($_.Exception.Message)" -ErrorAction Stop
                            }
                        }
                    }
                }
                else {
                    Write-Error -Message "Process aborted. The IP addresses $($ArrayDataNetworks.discovery_ip -join ", ") were not found as Target Portals and were not added. Cannot continue." -ErrorAction Stop
                }
            }
            else {
                Write-Verbose -Message "The Target Portals have been found. $($iSCSITArgetPortals.TargetPortalAddress -join ", ")"
            }
    
            if($iSCSITargetPortals.length -lt $ArrayDataNetworks.length) {
                Write-Warning -Message "$($Computer) does not have all of the iSCSI interfaces configured as target portals. We can still continue though."
            }
    
            Write-Verbose -Message "Check if the iscsi target is found in $($Computer)."
            $Attempts = 0
            while($Attempts -lt 5){
                try {                
                    Write-Verbose -Message "Getting iSCSI targets on $($Computer)"
                    $iSCSITarget = Get-IscsiTarget -NodeAddress $VolumeInformation.target_name -CimSession $Computer -ErrorAction Stop
                    Write-Verbose -Message "Volume $($VolumeName) has been found in $($Computer)."
                    break
                }
                catch {
                    Write-Verbose -Message "A volume with NodeAddress $($VolumeInformation.target_name) could not be found in $($Computer)."
                    if($Attempts -eq 4){
                        Write-Error -Message "The volume $($VolumeName) cannot be found in $($Computer). Please check the initiator group permissions, and try again." -ErrorAction Stop
                    }
                    else {
                        Write-Verbose -Message "Refreshing TargetPortals on $($Computer)"
                        Invoke-command -ComputerName $Computer -command { $using:ArrayDataNetworks | ForEach-Object { iscsicli RefreshTargetPortal $_.discovery_ip $using:IscsiTargetPortalPort } } | Out-Null
                        Write-Verbose -Message "Sleeping for 10 seconds and trying again."
                        Start-Sleep -Seconds 15
                        $Attempts++
                    }
                }
            }
    
            Write-Verbose -Message "Check if the iScsi drive is already connected."
            if(!($iSCSITarget.IsConnected)) {
                if($PSCmdlet.ShouldProcess($Computer, "Attach volume $($VolumeName).")) {

                    Write-Verbose -Message "Checking that the server has available iSCSI sessions."
                    $iSCSISessions = Invoke-Command -ComputerName $Computer -Command { (Get-IscsiSession).Count } 
                    if($iSCSISessions -gt 255) {
                        Write-Error -Message "$($Computer) has $($iSCSISessions) sessions. We cannot add any more."
                    }
    
                    $ConnectIscsiParameters = @{
                        NodeAddress = $iSCSITarget.NodeAddress
                        IsPersistent = $true 
                        IsMultipathEnabled = $true 
                        CimSession = $Computer
                    }
                    
                    Write-Verbose -Message "Connecting the nimble volume to the server."
                    try {
                        Connect-IscsiTarget @ConnectIscsiParameters -ErrorAction Stop
                        Write-Verbose -Message "The volume $($VolumeName) has been successfully connected to $($Computer)."
                    }
                    catch {
                        Write-Error -Message "Failed to connect the Nimble Volume $($VolumeName) to $($Computer). Error: $($_.Exception.Message)" -ErrorAction Stop
                    }          
                }
            }
            else {
                Write-Verbose -Message "The Volume has already been connected. Getting the iSCSI session to check that the Disk is online and initiated."
                $iSCSITarget | Get-IscsiSession -CimSession $Computer
            }
        }
    }
}
