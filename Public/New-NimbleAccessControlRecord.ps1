function New-NimbleAccessControlRecord {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $VolumeId,
        [Parameter(Position=1, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $InitiatorGroupId,
        # Array that you want to connect to.
        [Parameter(Position=2, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # Type of Access Control record that will be created. Choose from the following: 'volume', 'snapshot', 'both'. Default is 'both'
        [Parameter(Position=3, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('volume', 'snapshot', 'both')]
        [String]
        $ACRType = 'both'
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
        
        $uri = ($Global:NimbleApiUrls.GetACRecordsOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
        $data = @{
            "apply_to" = $ACRType
            "vol_id" = $VolumeId
            "initiator_group_id" = $InitiatorGroupId
        }

        $Body = ConvertTo-Json (@{ data = $data })
    }
    Process {

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        Write-Verbose -Message "Data passed to the API:"
        $data.Keys  | ForEach-Object { Write-Verbose -Message "$($_) = $($Data.$_)" }
        Write-Verbose -Message ""
        $RestMethodParams = @{
            Method = "Post"
            Uri = $uri
            Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
            Body = $Body
        }
        
        if($PSCmdlet.ShouldProcess($VolumeId, "Creating ACR with initiator group id $($InitiatorGroupId).")) {
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            
            (Invoke-RestMethod @RestMethodParams -ErrorAction Stop).Data

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }        
    }
}