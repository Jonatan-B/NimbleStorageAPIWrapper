function Get-NimbleInitiatorGroup {
    param(
        # Should we list all of the InitiatorGroups?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="ListInitiatorGroups")]
        [Switch]
        $List,
        # Should we list all of the InitiatorGroups?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="InitiatorGroupsDetail")]
        [Switch]
        $ListWithDetails,
        # Query for a specific InitiatorGroup ID
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="InitiatorGroupId")]
        [String]
        $InitiatorGroupId,
        # Query for a specific InitiatorGroup ID
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
        
        Write-Verbose -Message "The Global Nimble session is connected and not expired. Proceeding with getting the InitiatorGroups."
        
        switch($PSCmdlet.ParameterSetName){
            "ListInitiatorGroups" {
                $uri = ($Global:NimbleApiUrls.GetInitiatorGroupsOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
            "InitiatorGroupId" {
                $uri = ($Global:NimbleApiUrls.GetInitiatorGroupById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $InitiatorGroupId)
            }
            "InitiatorGroupsDetail" {
                $uri = ($Global:NimbleApiUrls.GetInitiatorGroupsDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
        }
    }
    Process {
        
        Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        try {
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