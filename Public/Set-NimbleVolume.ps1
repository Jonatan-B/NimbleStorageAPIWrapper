function Set-NimbleVolume {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # The volume id of the volume that will be modified
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [String]
        $VolumeId,
        # Array that you want to connect to.
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # Change the name of the volume
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $Name,
        # New description of the volume
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $Description,
        # New performance policy id that will be applied to the new volume
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $PerformancePolicyId,
        # Add volume to initiator group
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $VolumeCollectionId,
        # Should the MultiInitiator option be enabled?
        [Parameter(ValueFromPipelineByPropertyName)] 
        [ValidateSet("True","False")]
        [String]
        $MultiInitiator, 
        # Should the volume be set offline?
        [Parameter(ValueFromPipelineByPropertyName)] 
        [ValidateSet("True","False")]
        [String]
        $Online
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

        try {
            Get-NimbleVolume -VolumeId $VolumeId -ArrayUrl $ArrayUrl -ErrorAction Stop | Out-Null
        }
        catch {
            throw [Exception]::new("Unable to find Volume with id $($VolumeId). Error: $($_)")
        }

        $uri = ($Global:NimbleApiUrls.GetVolumeById -f $ArrayUrl, $VolumeId)
        
        $data = @{}

        if($MultiInitiator.IsPresent){
            $data.Add("multi_initiator", $true)
        }

        if($Online.IsPresent){
            $data.Add("online", $true)
        }

        if($Name){
            $data.Add("Name", $Name)
        }

        if($Description){
            $data.Add("description", $Description)
        }

        if($PerformancePolicyId){
            try {
                Get-NimblePerformancePolicy -PerformancePolicyId $PerformancePolicyId -ArrayUrl $ArrayUrl -ErrorAction Stop | Out-Null
                $data.Add("perfpolicy_id", $PerformancePolicyId)
            }
            catch {
                throw [Exception]::new("Unable to find the Performance Policy with ID $($PerformancePolicyId) on $($ArrayUrl).  Error: $($_)")
            }
        }

        if($VolumeCollectionId){
            try {
                Get-NimbleVolumeCollection -VolumeCollectionId $VolumeCollectionId -ArrayUrl $ArrayUrl -ErrorAction Stop | Out-Null
                $data.Add("volcoll_id", $VolumeCollectionId)
            }
            catch {
                throw [Exception]::new("Unable to find a Volume Collection with ID $($VolumeCollectionId) on $($ArrayUrl). Error: $($_)")
            }
        }

        $Body = ConvertTo-Json (@{ data = $data })
    }
    process {

        if($PSCmdlet.ShouldProcess($VolumeId, "Change configuration")) {
            Write-Verbose -Message "Invoking Method Put on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
            $RestMethodParams = @{
                Method = "PUT"
                Uri = $uri
                Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
                Body = $Body
            }

            Write-Verbose -Message "Data passed to the API:"
            $data.Keys  | ForEach-Object { Write-Verbose -Message "$($_) = $($data.$_)" }
            Write-Verbose -Message ""
            
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            
            try{
                (Invoke-RestMethod @RestMethodParams -ErrorAction Stop).Data
            }
            catch {
                $ErrorResults = Read-RestMethodError -ResultStream ($_.Exception.Response.GetResponseStream())   
                Write-Error -Message ($ErrorResults.Messages.Text -join " ") -ErrorId ($ErrorResults.Messages.Code -join ", ") -ErrorAction Stop
            }

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}