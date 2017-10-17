function Initialize-NimbleVolColHandover {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # The volume collection that will be handed over.
        [Parameter(Mandatory, Position=0)]
        [String]
        $SourceVolumeCollectionId,
        # The replication partner Id that the Volume Collection will be handed over to.
        [Parameter(Mandatory, Position=1)]
        [String]
        $ReplicationPartnerId,
        # Enable Reverse replication?
        [Parameter(Position=2)]
        [Switch]
        $ReverseReplication,
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
        
        $uri = ($Global:NimbleApiUrls.InvokeVolumeCollectionHandover -f $ArrayUrl)
        $data = @{
            "id" = $SourceVolumeCollectionId
            "replication_partner_id" = $ReplicationPartnerId
        }

        if($ReverseReplication.IsPresent){
            $data.Add("no_reverse","true")
        }

        $Body = ConvertTo-Json (@{ Data = $data })
    }
    process {

        if($PSCmdlet.ShouldProcess($SourceVolumeCollectionId, "Handover Collection to $($ReplicationPartnerId).")) {
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