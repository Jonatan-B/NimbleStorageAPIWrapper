function Sync-NimbleVolumeACR {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $VolumeId,
        # Array that you want to connect to.
        [Parameter(Position=1, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
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
        
        $VolumeObject = Get-NimbleVolume -VolumeId $VolumeId -ArrayUrl $ArrayUrl
        if($VolumeObject.volcoll_id){
            $VolumeCollectionObject = Get-NimbleVolumeCollection -VolumeCollectionId $VolumeObject.volcoll_id -ArrayUrl $ArrayUrl
        }
        else {
            throw "The provided volume is not part of a Volume Collection doesn't have a replication partner."
        }        

        if($VolumeCollectionObject.pol_owner_name -ne $ArrayUrl){
            $VolumeReplicationPartner = $VolumeCollectionObject.pol_owner_name
        }
        else {
            $VolumeReplicationPartner = $VolumeCollectionObject.schedule_list.downstream_partner
        }

        if($Global:NimbleSession."Session__$VolumeReplicationPartner"){
            if(($Global:NimbleSession."Session__$VolumeReplicationPartner".IsConnected -eq $false) -or ($Global:NimbleSession."Session__$VolumeReplicationPartner".IsTokenExpired() -eq $true)){

                throw "A session to $VolumeReplicationPartner already existed but is not longer connected, or has expired. Creating a new session."
            }
        }
        else {
            throw "Missing session to the partner array. Please create a new session with $($VolumeReplicationPartner)."
        }

        Write-Verbose -Message "Nimble session to $VolumeReplicationPartner is connected and not expired. Continuing."

        $ReplicationPartnerVolumeObject = Get-NimbleVolume -VolumeId $VolumeId -ArrayUrl $VolumeReplicationPartner
    }
    Process {
        
        Write-Verbose -Message "Gather the Access Control Record from each one of the volumes. Exclude the ones named *."
        $VolumeACR = $VolumeObject.access_control_records.initiator_group_name | Where-Object { $_ -ne '*' }
        $ReplicationPartnerVolumeACR = $ReplicationPartnerVolumeObject.access_control_records.initiator_group_name  | Where-Object { $_ -ne '*' }

        if($VolumeACR -eq $null){
            Write-Warning -Message "Volume $($VolumeObject.Name) on $($ArrayUrl) has no ACRs."
            $VolumeACR = @()
        }

        if($ReplicationPartnerVolumeACR -eq $null){
            Write-Warning -Message "Volume $($ReplicationPartnerVolumeObject.Name) on $($VolumeReplicationPartner) has no ACRs."
            $ReplicationPartnerVolumeACR = @()
        }

        Write-Verbose -Message "Volume has $($VolumeACR.Count) ACRs. Partner has $($ReplicationPartnerVolumeACR.Count) ACRs."
        Write-Verbose -Message "Checking both sides ACR's to look for discrepancies."
        $OutOfSyncACR = Compare-Object -ReferenceObject $VolumeACR -DifferenceObject $ReplicationPartnerVolumeACR
        
        if($OutOfSyncACR){
            
            foreach($ACR in $OutOfSyncACR){
                
                $SideIndicator = $ACR.SideIndicator
                switch($SideIndicator){
                    "<=" {
                        Write-Host "Volume $($VolumeObject.Name):$($ArrayUrl) <= $($VolumeObject.Name):$($VolumeReplicationPartner)." -ForegroundColor DarkYellow
                        $ACRObject = $VolumeObject.access_control_records | Where-Object {$_.initiator_group_name -eq $ACR.InputObject}
                        Write-Verbose -Message "ACR for Initiator Group '$($ACRObject.initiator_group_name)' missing for volume $($ReplicationPartnerVolumeObject.Name) on $($VolumeReplicationPartner).`n"
                        
                        $ReplicationPartnerInitiatorGroup = Get-NimbleInitiatorGroup -List -ArrayUrl $VolumeReplicationPartner | Where-Object { $_.Name -eq $ACRObject.initiator_group_name}
                        if($ReplicationPartnerInitiatorGroup){
                            Write-Verbose -Message "Creating new ACR"
                            Write-Verbose -Message "----------------"
                            Write-Verbose -Message "Volume Id: $($ACRObject.vol_id)"
                            Write-Verbose -Message "Initiator Group Id: $($ReplicationPartnerInitiatorGroup.id)"
                            Write-Verbose -Message "Array: $($VolumeReplicationPartner)"
                            if($PSCmdlet.ShouldProcess($ACRObject.vol_id, "Creating ACR with initiator group $($ACRObject.initiator_group_name) on $($VolumeReplicationPartner).")) {
                                
                                try {
                                    $results = New-NimbleAccessControlRecord -VolumeId $ACRObject.vol_id -InitiatorGroupId $ReplicationPartnerInitiatorGroup.id -ArrayUrl $VolumeReplicationPartner -ErrorAction Stop
                                    $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $VolumeReplicationPartner
                                    $results
                                }
                                catch {
                                    Write-Verbose -Message "I've found that sometimes the method will fail, but it'll still create the rule. We'll manually make sure."
                                    $VolumeACR = (Get-NimbleVolume -VolumeId $ACRObject.vol_id -ArrayUrl $VolumeReplicationPartner).Access_control_records | 
                                    Where-Object { $_.initiator_group_id -eq $InitiatorGroup.id }
                                
                                    Try {
                                        $newACR = Get-NimbleAccessControlRecord -AccessControlRecordId $VolumeACR.id -ArrayUrl $VolumeReplicationPartner -ErrorAction Stop
                                        $newACR | Add-Member -MemberType NoteProperty -Name "Array" -Value $VolumeReplicationPartner
                                        $newACR    
                                    }
                                    catch {
                                        Write-Error -Message "Failed to create new ACR. $($_.Exception.Message)."
                                        continue
                                    }
                                }
                                
                            }
                            Write-Verbose -Message "Created successfully.`n"
                        }
                        else {
                            Write-Error -Message "Unable to find the initiator group $($ACRObject.initiator_group_name) in $($VolumeReplicationPartner)." -RecommendedAction "Create the initiator group and try again."
                        }
                        
                        Continue
                    }
                    "=>" {
                        Write-Host "Volume $($VolumeObject.Name):$($ArrayUrl) => $($VolumeObject.Name):$($VolumeReplicationPartner)." -ForegroundColor DarkYellow
                        $ACRObject = $ReplicationPartnerVolumeObject.access_control_records | Where-Object {$_.initiator_group_name -eq $ACR.InputObject}
                        Write-Verbose -Message "ACR for Initiator Group '$($ACRObject.initiator_group_name)' missing for volume $($VolumeObject.Name) on $($ArrayUrl).`n"

                        $InitiatorGroup = Get-NimbleInitiatorGroup -List -ArrayUrl $ArrayUrl | Where-Object { $_.Name -eq $ACRObject.initiator_group_name}

                        if($InitiatorGroup){
                            Write-Verbose -Message "Creating new ACR"
                            Write-Verbose -Message "----------------"
                            Write-Verbose -Message "Volume Id: $($ACRObject.vol_id)"
                            Write-Verbose -Message "Initiator Group Id: $($InitiatorGroup.id)"
                            Write-Verbose -Message "Array: $($ArrayUrl)"
                            if($PSCmdlet.ShouldProcess($ACRObject.vol_id, "Creating ACR with initiator group $($ACRObject.initiator_group_name) on $($ArrayUrl).")) {
                                try {
                                    $results = New-NimbleAccessControlRecord -VolumeId $ACRObject.vol_id -InitiatorGroupId $InitiatorGroup.id -ArrayUrl $ArrayUrl -ErrorAction Stop
                                    $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $ArrayUrl
                                    $results
                                }
                                catch {
                                    Write-Verbose -Message "I've found that sometimes the method will fail, but it'll still create the rule. We'll manually make sure."
                                    $VolumeACR = (Get-NimbleVolume -VolumeId $ACRObject.vol_id -ArrayUrl $ArrayUrl).Access_control_records | 
                                        Where-Object { $_.initiator_group_id -eq $InitiatorGroup.id }
                                    
                                    Try {
                                        $newACR = Get-NimbleAccessControlRecord -AccessControlRecordId $VolumeACR.id -ArrayUrl $ArrayUrl -ErrorAction Stop
                                        $newACR | Add-Member -MemberType NoteProperty -Name "Array" -Value $ArrayUrl
                                        $newACR    
                                    }
                                    catch {
                                        Write-Error -Message "Failed to create new ACR. $($_.Exception.Message)."
                                        continue
                                    }                                    
                                }
                            }
                            Write-Verbose -Message "Created successfully.`n"
                        }
                        else {
                            Write-Error -Message "Unable to find the initiator group $($ACRObject.initiator_group_name) in $($VolumeReplicationPartner)." -RecommendedAction "Create the initiator group and try again."
                        }

                        Continue
                    }
                }
            }
        }
        else {
            Write-Host "Volume $($VolumeObject.Name):$($ArrayUrl) == $($VolumeObject.Name):$($VolumeReplicationPartner)." -ForegroundColor Green
            return
        }      
    }
}