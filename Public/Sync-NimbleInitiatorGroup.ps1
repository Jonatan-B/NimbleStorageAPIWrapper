function Sync-NimbleInitiatorGroup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $PartnerArray,
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

        Write-Verbose -Message "Gathering the Inititator groups from each array."
        $ArrayInitiatorGroups = Get-NimbleInitiatorGroup -ListWithDetails -ArrayUrl $ArrayUrl
        $PartnerArrayInitiatorGroups = Get-NimbleInitiatorGroup -ListWithDetails -ArrayUrl $PartnerArray
        Write-Verbose -Message "Array has $($ArrayInitiatorGroups.Count) groups. Partner has $($PartnerArrayInitiatorGroups.Count) groups."

        Write-Verbose -Message "Checking both arrays for missing groups.";
        $OutOfSyncIGroup = Compare-Object -ReferenceObject $ArrayInitiatorGroups -DifferenceObject $PartnerArrayInitiatorGroups -Property Name -PassThru

        if($OutOfSyncIGroup){
            Write-Verbose -Message "Discrepancies found in the initiator groups."

            foreach($Group in $OutOfSyncIGroup){
                
                $SideIndicator = $Group.SideIndicator
                switch($SideIndicator){
                    "<=" {
                        Write-Verbose -Message "Initiator Group $($Group.full_name) missing from $($PartnerArray)."
                        $CreateIGParameters = @{
                            Name = $Group.full_name
                            Protocol = $Group.access_protocol
                            Description =  "Copied by Sync-NimbleInitiatorGroup cmdlet from $($ArrayUrl)."
                            ArrayUrl = $PartnerArray
                        }
                        
                        Write-Verbose -Message ""
                        Write-Verbose -Message "Creating Initiator Group"
                        Write-Verbose -Message "------------------------"
                        $CreateIGParameters.Keys | ForEach-Object { Write-Verbose "$($_): $($CreateIGParameters.$_)" }
                        Write-Verbose -Message ""

                        if($PSCmdlet.ShouldProcess($Group.full_name, "Create initiator group on $($PartnerArray)")) {
                            $results = New-NimbleInitiatorGroup @CreateIGParameters -ErrorAction Stop 
                            $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $PartnerArray
                            $results
                        }
                    }
                    "=>" {
                        Write-Verbose -Message "Initiator Group $($Group.full_name) missing from $($ArrayUrl)."
                        $CreateIGParameters = @{
                            Name = $Group.full_name
                            Protocol = $Group.access_protocol
                            Description =  "Copied by Sync-NimbleInitiatorGroup cmdlet from $($PartnerArray)."
                            ArrayUrl = $ArrayUrl
                        }
                        
                        Write-Verbose -Message ""
                        Write-Verbose -Message "Creating Initiator Group"
                        Write-Verbose -Message "------------------------"
                        $CreateIGParameters.Keys | ForEach-Object { Write-Verbose "$($_): $($CreateIGParameters.$_)" }
                        Write-Verbose -Message ""
                        
                        if($PSCmdlet.ShouldProcess($Group.full_name, "Create initiator group on $($ArrayUrl)")) {
                            $results = New-NimbleInitiatorGroup @CreateIGParameters -ErrorAction Stop 
                            $results | Add-Member -MemberType NoteProperty -Name "Array" -Value $ArrayUrl
                            $results
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