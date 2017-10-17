function Set-NimbleVolMultiInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # The volume id of the volume that will be modified
        [Parameter(Mandatory, Position=0)]
        [String]
        $VolumeId,
        # Should the MultiInitiator option be enabled?
        [Parameter(Mandatory, Position=1)]
        [Bool]
        $Enable,
        # Array that you want to connect to.
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

        $uri = ($Global:NimbleApiUrls.GetVolumeById -f $ArrayUrl, $VolumeId)
        
        $data = @{
            multi_initiator = $false
        }

        if($Enable){
            $data.multi_initiator = $true
        }

        $Body = ConvertTo-Json (@{ Data = $data })
    }
    process {

        if($PSCmdlet.ShouldProcess($VolumeId, "Set MultiInitiator Option")) {
            Write-Verbose -Message "Invoking Method Post on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
            $RestMethodParams = @{
                Method = "Post"
                Uri = $uri
                Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
                Body = $Body
            }
            
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            
            Invoke-RestMethod @RestMethodParams -ErrorAction Stop

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}