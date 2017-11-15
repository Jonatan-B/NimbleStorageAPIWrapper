function New-NimbleInitiatorGroup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Volume Id where the new Record will be added to.
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $Name,
        # What protocol will the Initiator group be used for? (Set: 'iscsi', 'fc')
        [Parameter(Position=1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('iscsi')]
        [String]
        $Protocol,
        # Array that you want to connect to.
        [Parameter(Position=2, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # Description to be added to the new Initiator Group.
        [Parameter(Position=2, ValueFromPipelineByPropertyName)]
        [String]
        $Description = "Created by the module PsNimbleApi"
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
        
        $uri = ($Global:NimbleApiUrls.GetInitiatorGroupsOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
        $data = @{
            name = $Name
            access_protocol = $Protocol
            description = $Description
        }

        $Body = ConvertTo-Json (@{ data = $data })
    }
    Process {
        
        Write-Verbose -Message "Invoking Method Get on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        Write-Verbose -Message "Data passed to the API:"
        $data.Keys  | ForEach-Object { Write-Verbose -Message "$($_) = $($Data.$_)" }
        Write-Verbose -Message ""

        $RestMethodParams = @{
            Method = "Post"
            Uri = $uri
            Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
            Body = $Body
        }
        
        if($PSCmdlet.ShouldProcess($Name, "Create new initiator group with Protocol $($Protocol).")) {
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