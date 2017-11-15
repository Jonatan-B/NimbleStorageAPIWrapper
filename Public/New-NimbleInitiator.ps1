function New-NimbleInitiator {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # The protocol that will be used by the initiator.
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("iscsi")]
        [String]
        $Protocol,
        # The Initiator Group Id where the new initiator be added to.
        [Parameter(Position=1, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $InitiatorGroupId,
        # The Iqn name that the machine will use for the iscsi connection.
        [Parameter(Position=2, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $Iqn,
        # Array that you want to connect to.
        [Parameter(Position=3, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # Ip Address to be used for iscsi authentication along witht he iqn. Default is '*' (Allow all)
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $IpAddress="*",
        # The friendly name to be given to the initiator. Default is same as Iqn.
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $Label = $Iqn
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
        
        $uri = ($Global:NimbleApiUrls.GetInitiatorsOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
        $data = @{
            access_protocol = $Protocol
            initiator_group_id = $InitiatorGroupId
            label = $Label
            iqn = $Iqn
        }
        
        if($IpAddress -ne "*"){
            $data.Add("ip_address", $IpAddress)
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