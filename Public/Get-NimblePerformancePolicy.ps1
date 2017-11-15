function Get-NimblePerformancePolicy {
    param(
        # Should we list all of the Performance Policies?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="ListPerformancePolicies")]
        [Switch]
        $List,
        # Should we list all of the Performance Policies?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="PerformancePoliciesDetail")]
        [Switch]
        $ListWithDetails,
        # Query for a specific Performance Policy ID
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="PerformancePolicyId")]
        [String]
        $PerformancePolicyId,
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
        
        switch($PSCmdlet.ParameterSetName){
            "ListPerformancePolicies" {
                $uri = ($Global:NimbleApiUrls.GetPerformancePoliciesOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
            "PerformancePolicyId" {
                $uri = ($Global:NimbleApiUrls.GetPerformancePolicyById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $PerformancePolicyId)
            }
            "PerformancePoliciesDetail" {
                $uri = ($Global:NimbleApiUrls.GetPerformancePoliciesDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
        }
    }
    Process {
        
        Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        try{
            (Invoke-RestMethod -Uri $uri -Method Get -Header $Global:NimbleSession."Session__$ArrayUrl".SessionHeader -ErrorAction Stop).Data
        }
        catch {
            $ErrorResults = Read-RestMethodError -ResultStream ($_.Exception.Response.GetResponseStream())   
            Write-Error -Message ($ErrorResults.Messages.Text -join " ") -ErrorId ($ErrorResults.Messages.Code -join ", ") -ErrorAction Stop
        }

        Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        
    }
}