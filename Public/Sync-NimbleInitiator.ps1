function Sync-NimbleInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $PartnerArray,
        # Array that you want to connect to.
        [Parameter(Position=1, Mandatory, ValueFromPipelineByPropertyName)]
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

        if($Global:NimbleSession."Session__$PartnerArray"){
            if(($Global:NimbleSession."Session__$PartnerArray".IsConnected -eq $false) -or ($Global:NimbleSession."Session__$PartnerArray".IsTokenExpired() -eq $true)){

                throw "A session to $($PartnerArray) already existed but is not longer connected, or has expired. Creating a new session."
            }
        }
        else {
            throw "Missing session to the partner array. Please create a new session."
        }

        Write-Verbose -Message "Nimble session to $PartnerArray is connected and not expired. Continuing." 
    }
    Process {
        
        Write-Verbose -Message "Gathering the Inititators from each array."
        $ArrayInitiators = Get-NimbleInitiator -ListWithDetails -ArrayUrl $ArrayUrl
        $PartnerArrayInitiators = Get-NimbleInitiator -ListWithDetails -ArrayUrl $PartnerArray
        
        # Clean any damn whitespaces at the beginning of the iqn.
        $ArrayInitiators = $ArrayInitiators | Select-Object @{n="Iqn";e={ $_.Iqn -replace "^\s+", "" }}, * -ExcludeProperty Iqn
        $PartnerArrayInitiators = $PartnerArrayInitiators | Select-Object @{n="Iqn";e={ $_.Iqn -replace "^\s+", "" }}, * -ExcludeProperty Iqn
        
        Write-Verbose -Message "Array has $($ArrayInitiators.Count) initiators. Partner has $($PartnerArrayInitiators.Count) initiators."

        Write-Verbose -Message "Checking both arrays for missing initiators.";
        $OutOfSyncInitiators = Compare-Object -ReferenceObject $ArrayInitiators -DifferenceObject $PartnerArrayInitiators -Property Iqn, initiator_group_name -PassThru

        if($OutOfSyncInitiators){
            Write-Verbose -Message "Discrepancies found in the initiators between the arrays."

            foreach($Initiator in $OutOfSyncInitiators){
                
                $SideIndicator = $Initiator.SideIndicator
                switch($SideIndicator){
                    "<=" {
                        Write-Verbose -Message "Initiator $($Initiator.Label) missing from $($PartnerArray)."
                        Write-Verbose -Message "Getting the Initiator Group Id for $($Initiator.initiator_group_name) from $($ArrayUrl), so we can create the Initiator there."
                        $PartnerInitiatorGroupId = Get-NimbleInitiatorGroup -List -ArrayUrl $PartnerArray | Where-Object { $_.Name -eq $Initiator.initiator_group_name } | Select-Object -ExpandProperty id

                        if($PartnerInitiatorGroupId){
                            $CreateIGParameters = @{
                                Protocol = $Initiator.access_protocol
                                InitiatorGroupId = $PartnerInitiatorGroupId
                                Iqn = $Initiator.Iqn
                                ArrayUrl = $PartnerArray
                                Label = $Initiator.Label
                                IpAddress = $Initiator.ip_address
                            }
                            
                            Write-Verbose -Message ""
                            Write-Verbose -Message "Creating Initiator"
                            Write-Verbose -Message "------------------"
                            $CreateIGParameters.Keys | ForEach-Object { Write-Verbose "$($_): $($CreateIGParameters.$_)" }
                            Write-Verbose -Message ""

                            if(Get-NimbleInitiator -ListWithDetails -ArrayUrl $PartnerArray | Where-Object { $_.Iqn -eq $Initiator.Iqn -and $_.initiator_group_id -eq $PartnerInitiatorGroupId }){
                                Write-Error -Message "An initiator with $($Initiator.Iqn) and $($Initiator.initiator_group_name) already exists on $($PartnerArray)."
                                continue
                            }
    
                            if($PSCmdlet.ShouldProcess($PartnerArray, "Create initiator with iqn ($($Initiator.iqn))")) {

                                try {
                                    $results = New-NimbleInitiator @CreateIGParameters -ErrorAction Stop
                                    $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $PartnerArray
                                    $results
                                }
                                catch {
                                    Write-Error -Message "Failed to create initiator $($Initiator.Label) with assigned initiator group $($Initiator.initiator_group_name) on array $($PartnerArray). Reason: $($_.Exception.Message)"
                                    continue
                                }
                                
                            }
                        }
                        else {
                            Write-Warning -Message "An Initiator Group with Name $($Initiator.initiator_group_name) does not exist in $($PartnerArray). Could not create Initiator."
                            continue
                        }                        
                    }
                    "=>" {
                        Write-Verbose -Message "Initiator  $($Initiator.Label) missing from $($ArrayUrl)."
                        Write-Verbose -Message "Getting the Initiator Group Id for $($Initiator.initiator_group_name) from $($ArrayUrl), so we can create the Initiator there."
                        $PartnerInitiatorGroupId = Get-NimbleInitiatorGroup -List -ArrayUrl $ArrayUrl | Where-Object { $_.Name -eq $Initiator.initiator_group_name } | Select-Object -ExpandProperty id

                        if($PartnerInitiatorGroupId){

                            $CreateIGParameters = @{
                                Protocol = $Initiator.access_protocol
                                InitiatorGroupId = $PartnerInitiatorGroupId
                                Iqn = $Initiator.Iqn
                                ArrayUrl = $ArrayUrl
                                Label = $Initiator.Label
                                IpAddress = $Initiator.ip_address
                            }
                            
                            Write-Verbose -Message ""
                            Write-Verbose -Message "Creating Initiator "
                            Write-Verbose -Message "------------------------"
                            $CreateIGParameters.Keys | ForEach-Object { Write-Verbose "$($_): $($CreateIGParameters.$_)" }
                            Write-Verbose -Message ""

                            if(Get-NimbleInitiator -ListWithDetails -ArrayUrl $ArrayUrl | Where-Object { $_.Iqn -eq $Initiator.Iqn -and $_.initiator_group_id -eq $PartnerInitiatorGroupId }){
                                Write-Error -Message "An initiator with $($Initiator.Iqn) and $($Initiator.initiator_group_name) already exists on $($ArrayUrl)."
                                continue
                            }
                            
                            if($PSCmdlet.ShouldProcess($ArrayUrl, "Create initiator with iqn ($($Initiator.iqn))")) {                                

                                try {
                                    $results = New-NimbleInitiator @CreateIGParameters -ErrorAction Stop
                                    $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $ArrayUrl
                                    $results
                                }
                                catch {
                                    Write-Error -Message "Failed to create initiator $($Initiator.Label) with assigned initiator group $($Initiator.initiator_group_name) on array $($ArrayUrl). Reason: $($_.Exception.Message)"
                                    continue
                                }
                            }
                        }
                        else {
                            Write-Warning -Message "An Initiator Group with Name $($Initiator.initiator_group_name) does not exist in $($ArrayUrl). Could not create Initiator."
                            continue
                        }  
                        
                    }
                }
            }
        }
        else {
            Write-Verbose -Message "Arrays are synched."
        }                            
    }
}