function Remove-NimbleInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # The Initiator Group Id where the new initiator be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $InitiatorId,
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
        
        $uri = ($Global:NimbleApiUrls.GetInitiatorById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $InitiatorId)
    }
    Process {
        
        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."

        $RestMethodParams = @{
            Method = "Delete"
            Uri = $uri
            Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
        }
        
        if($PSCmdlet.ShouldProcess($Iqn, "Create new initiator group with Protocol $($Protocol).")) {
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