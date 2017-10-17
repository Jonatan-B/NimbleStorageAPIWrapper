function Get-NimbleNetworkAdapter {
    param(
        # Should we list all of the Initiators?
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="ListNetworkAdapters")]
        [Switch]
        $List,
        # Should we list all of the Initiators?
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="ListNetworkAdaptersWithDetails")]
        [Switch]
        $ListWithDetails,
        # Query for a specific Initiator ID
        [Parameter(Position=0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="NetworkAdapterId")]
        [String]
        $NetworkAdapterId,
        # The Url of the Nimble Array.
        [Parameter(Position=1, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # What network interface should be returned?
        [Parameter(Position=2, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="ListNetworkAdaptersWithDetails")]
        [Parameter(ParameterSetName="ListNetworkAdapters")]
        [ValidateSet("Active","Backup","*")]
        [String]
        $AdapterRole
        
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
            "ListNetworkAdapters" {
                $uri = ($Global:NimbleApiUrls.GetNetworkAdapterOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)

                if($AdapterRole -ne "*"){
                    $uri = $uri + "?role=$($AdapterRole.ToLower())"
                }
            }
            "NetworkAdapterId" {
                $uri = ($Global:NimbleApiUrls.GetNetworkAdapaterById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $NetworkAdapterId)
            }
            "ListNetworkAdaptersWithDetails" {
                $uri = ($Global:NimbleApiUrls.GetNetworkAdapterDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)

                if($AdapterRole -ne "*"){
                    $uri = $uri + "?role=$($AdapterRole.ToLower())"
                }
            }
        }
    }
    process {
        Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."

        

        $ApiCallResult = Invoke-RestMethod -Uri $uri -Method Get -Header $Global:NimbleSession."Session__$ArrayUrl".SessionHeader -ErrorAction Stop
        $ApiCallResult.Data 

        Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}