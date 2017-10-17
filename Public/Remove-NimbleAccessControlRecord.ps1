function Remove-NimbleAccessControlRecord {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("ACRId")]
        [String]
        $AccessControlRecordId,
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
        
        $uri = ($Global:NimbleApiUrls.GetACRecordById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $AccessControlRecordId)
    }
    Process {

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        
        $RestMethodParams = @{
            Method = "Delete"
            Uri = $uri
            Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
        }
        
        if($PSCmdlet.ShouldProcess($VolumeId, "Delete ACR")) {
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            
            Invoke-RestMethod @RestMethodParams -ErrorAction Stop

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}