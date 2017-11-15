function Get-NimbleInitiator {
    param(
        # Should we list all of the Initiators?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="ListInitiators")]
        [Switch]
        $List,
        # Should we list all of the Initiators?
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="InitiatorsDetail")]
        [Switch]
        $ListWithDetails,
        # Query for a specific Initiator ID
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName="InitiatorId")]
        [String]
        $InitiatorId,
        # Query for a specific Initiator ID
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
        
        Write-Verbose -Message "The Global Nimble session is connected and not expired. Proceeding with getting the Initiators."
        
        switch($PSCmdlet.ParameterSetName){
            "ListInitiators" {
                # The regular 'none details' query only returns the Id, and wasn't very useful. 
                # I changed the detailed view to only include id and label instead of all of the data. 
                $uri = ("$($Global:NimbleApiUrls.GetInitiatorsDetails)?fields=id,label" -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
            "InitiatorId" {
                $uri = ($Global:NimbleApiUrls.GetInitiatorById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $InitiatorId)
            }
            "InitiatorsDetail" {
                $uri = ($Global:NimbleApiUrls.GetInitiatorsDetails -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
            }
        }
    }
    Process {
        
        Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        try {
            (Invoke-RestMethod -Uri $uri -Method Get -Header $Global:NimbleSession."Session__$ArrayUrl".SessionHeader -ErrorAction Stop).data
        }
        catch {
            $ErrorResults = Read-RestMethodError -ResultStream ($_.Exception.Response.GetResponseStream())   
            Write-Error -Message ($ErrorResults.Messages.Text -join " ") -ErrorId ($ErrorResults.Messages.Code -join ", ") -ErrorAction Stop
        }

        Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        
    }
}