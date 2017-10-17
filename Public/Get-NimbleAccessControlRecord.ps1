function Get-NimbleAccessControlRecord {
    param(
        # Should we list all of the AccessControlRecords?
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="ListAccessControlRecords")]
        [Switch]
        $List,
        # Should we list all of the AccessControlRecords?
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="AccessControlRecordDetail")]
        [Switch]
        $ListWithDetails,
        # Query for a specific AccessControlRecord ID
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="AccessControlRecordId")]
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
        
        switch($PSCmdlet.ParameterSetName){
            "ListAccessControlRecords" {
                $uri = ($Global:NimbleApiUrls.GetACRecordsOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
            "AccessControlRecordId" {
                $uri = ($Global:NimbleApiUrls.GetACRecordById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $AccessControlRecordId)
            }
            "AccessControlRecordDetail" {
                $uri = ($Global:NimbleApiUrls.GetACRecordsDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
        }
    }
    Process {
        
        Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        $ApiCallResult = Invoke-RestMethod -Uri $uri -Method Get -Header $Global:NimbleSession."Session__$ArrayUrl".SessionHeader -ErrorAction Stop
        $ApiCallResult.Data

        Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        
    }
}