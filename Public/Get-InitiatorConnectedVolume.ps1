function Get-InitiatorConnectedVolume {
    param(
        # Username to use for the Nimble Connection
        [Parameter(Mandatory, Position=0)]
        [String]
        $Username,
        # Password to use for the Nimble Connection
        [Parameter(Mandatory, Position=1)]
        [SecureString]
        $Password,
        # Array that you want to connect to.
        [Parameter(Mandatory, Position=2)]
        [String[]]
        $NimbleArray
    )
    begin {
        Write-Verbose -Message "Going through each Array in the NimbleArray parameter and connecting with the provided credentials."
        foreach($ArrayUrl in $NimbleArray){

            if($Global:NimbleSession."Session__$ArrayUrl"){
                if(($Global:NimbleSession."Session__$ArrayUrl".IsConnected -eq $false) -or ($Global:NimbleSession."Session__$ArrayUrl".IsTokenExpired() -eq $true)){
    
                    Write-Verbose -Message "A session already existed but is not longer connected, or has expired. Creating a new session."
                    $Global:NimbleSession.Remove("Session__$ArrayUrl")
                }
                else {
                    Write-Verbose "A valid session for $($ArrayUrl) has already been created."
                }
            }
            else {
                Write-Verbose -Message "Creating a new session to $($ArrayUrl)"
                New-NimbleApiSession -ArrayUrl $ArrayUrl -Username $Username -Password $Password
            }
        }
    }
    process {
        Write-Verbose -Message "Gathering all of the Nimble Initiators, and removing duplicates."
        $InitiatorsList = $Global:NimbleSession.values.nimbleArrayUrl | ForEach-Object { Get-NimbleInitiator -ListWithDetails -ArrayUrl $_ } | Select-Object -ExpandProperty Iqn -Unique

        Write-Verbose -Message "Gathering all Volumes. These will be used later."
        $NimbleVolumes = $Global:NimbleSession.values.nimbleArrayUrl | ForEach-Object { $Array = $_; Get-NimbleVolume -ListWithDetails -ArrayUrl $_ | Select-Object -Property *, @{N="Array";E={$Array}} }
        
        foreach($Initiator in $InitiatorsList){
            
            $ServerDnsHostname = $Initiator.substring($Initiator.indexOf(":")+1)
            
            Write-Verbose -Message "Initiator for $ServerDnsHostname has been found."
            if(!(Test-NetConnection -ComputerName $ServerDnsHostname -Port 135 -InformationLevel Quiet -Verbose:$false)){
                Write-Warning -Message "The server $ServerDnsHostname, acquired from the iqn, could not be found."
                Continue
            }

            Write-Verbose -Message "Gathering Iscsi Targets from the server."
            try{
                $iScsiTargets = Get-IscsiTarget -CimSession $ServerDnsHostname -ErrorAction Stop -Verbose:$false | Where-Object IsConnected -eq $true
            }
            catch {
                Write-Verbose -Message "Get-IscsiTarget cmdlet failed with error $($_.Exception.Message). Skipping"
                try {
                    Write-Verbose -Message "Get-IscsiTarget failed. Attempting to grab the data using Get-CimClass."
                    $iScsiTargets = Get-CimInstance -ClassName MSFT_IscsiTarget -Namespace Root/Microsoft/Windows/Storage -CimSession $ServerDnsHostname -ErrorAction Stop | Where-Object IsConnected -eq $true
                }
                catch {
                    Write-Verbose -Message "Get-CimInstance failed as well. Performing a query call using iscsicli."
                    try { 
                        $iScsiCliResult = Invoke-Command -ComputerName $ServerDnsHostname -Command {Invoke-Expression "iscsicli ReportTargetMappings"} -ErrorAction Stop
                        $iScsiTargets = (($iScsiCliResult | Where-Object { $_ -match "Target Name"}) -split " : ")[1] | ForEach-Object {New-Object -TypeName Psobject -Property @{IsConnected = $true; NodeAddress = $_; PSComputerName = $ServerDnsHostname}}
                    }
                    catch {
                        $Properties = [ordered]@{
                            "ComputerName" = $ServerDnsHostname
                            "HostStatus" = "Unable to gather iScsi targets through Get-Iscsitarget, Get-CimInstance, or iscsiCli.exe"
                            "InitiatorIqn" = $null
                            "iScsiTargetNodeAddress" = $null
                            "VolumeName" = $null
                            "VolumeCollectionName" = $null
                            "VolumeSize" = $null
                            "VolumePerformancePolicy" = $null
                            "ArrayConnection" = $null
                        }
    
                        $HostsConnectedVolumes = New-Object -TypeName Psobject -Property $Properties -Verbose:$false
    
                        $HostsConnectedVolumes
                        Continue
                    }
                    
                }
            }
            
            if($iScsiTargets){
                Write-Verbose -Message "$($IscsiTargets.Count) targets found."
                
                Foreach($ConnectedDrive in $iScsiTargets){
                
                    Write-Verbose -Message "Looking for the Nimble volume with the IscsiTarget from the host."
                    $ConnectedVolume = $NimbleVolumes | Where-Object {$_.Target_Name -eq $ConnectedDrive.NodeAddress}

                    if($ConnectedVolume){
                        $Properties = [ordered]@{
                            "ComputerName" = $ConnectedDrive.PSComputerName
                            "HostStatus" = "Online"
                            "InitiatorIqn" = $Initiator
                            "iScsiTargetNodeAddress" = $ConnectedDrive.NodeAddress
                            "VolumeName" = $ConnectedVolume.name
                            "VolumeCollectionName" = $ConnectedVolume.volcoll_name
                            "VolumeSize" = $ConnectedVolume.size
                            "VolumePerformancePolicy" = $ConnectedVolume.perfpolicy_name
                            "ArrayConnection" = $ConnectedVolume.Array
                        }
                        
                        Write-Verbose -Message "Creating a new Object with the discovered information."
                        $HostsConnectedVolumes = New-Object -TypeName Psobject -Property $Properties -Verbose:$false
    
                        $HostsConnectedVolumes
                    }
                    else {
                        Write-Warning -Message "A Volume with Target_Name $($ConnectedDrive.NodeAddress) could not be found in the arrays $($NimbleArray -join ", ")."
                        Continue
                    }

                }
            }
            else {
                Write-Warning -Message "Server $($ServerDnsHostname) is in the inititators list, but has no connected volumes."
            }
        }
    }
}