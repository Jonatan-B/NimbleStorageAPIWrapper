function Get-NimbleVolumeCollection {
    param(
        # Should we list all of the VolumeCollections?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="ListVolumeCollections")]
        [Switch]
        $List,
        # Should we list all of the VolumeCollections with details?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="VolumeCollectionsDetail")]
        [Switch]
        $ListWithDetails,
        # Query for a specific VolumeCollection ID
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="VolumeCollectionId")]
        [String]
        $VolumeCollectionId,
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
            "ListVolumeCollections" {
                $uri = ($Global:NimbleApiUrls.GetVolumeCollectionOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
            "VolumeCollectionId" {
                $uri = ($Global:NimbleApiUrls.GetVolumeCollectionById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $VolumeCollectionId)
            }
            "VolumeCollectionsDetail" {
                $uri = ($Global:NimbleApiUrls.GetVolumeCollectionDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
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