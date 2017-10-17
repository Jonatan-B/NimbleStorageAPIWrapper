class NimbleApiSession {
    [PsCredential] $Credentials
    [String] $NimbleArrayUrl
    [PSCustomObject] $TokenObject
    [String] $TokenSessionId
    [String] $TokenId
    [DateTime] $TokenCreationTime
    [DateTime] $TokenExpirationTime
    [HashTable] $SessionHeader
    [bool] $IsConnected = $false

    NimbleApiSession(){}

    NimbleApiSession([PsCredential]$Credentials, [string]$NimbleUrl){
        $this.Credentials = $Credentials
        $this.NimbleArrayUrl = $NimbleUrl
        $this.IsConnected = $this.CreateSession()
        if($this.IsConnected){
            if($this.TokenObject){
                $this.TokenId = $this.TokenObject.Id
                $this.TokenSessionId = $this.TokenObject.session_token
                $this.TokenCreationTime = [NimbleApiSession]::ConvertEpochToDate($this.TokenObject.creation_time)
                $this.TokenExpirationTime = $this.TokenCreationTime.AddMinutes(30)
                $this.SessionHeader = @{ "X-Auth-Token" = $this.TokenSessionId }
            }
            else {
                Write-Error "It seems the CreateSession method returned true, but the TokenObject property is null. Wtf mante." -ErrorAction Stop
            }

            # Since we were able to get a Token we'll now dispose of the Credentials variable.
            $this.Credentials = $null
        }
    }

    static [DateTime] ConvertEpochToDate($SecondsSinceEpoch){
        [DateTime]$epoch = Get-Date '1970-01-01 00:00:00' 
        return $epoch.AddSeconds($SecondsSinceEpoch)
    }

    [Bool] CreateSession() {
        Write-Verbose -Message "Creating a new Nimble Session."

        try {
            Write-Verbose -Message "Checking if the IgnoreSSLWarning Type is added."
            [IgnoreSSLWarning]
        }
        catch {
            Write-Verbose -Message "IgnoreSSLWarning Type is not added. Adding."
            Add-IgnoreSSLWarningType
        }

        try {

            Write-Verbose -Message "Creating the Data hashtable containing the username ($($this.Credentials.UserName)), and password."
            $Data = @{
                username = $this.Credentials.UserName       
                password = $this.Credentials.GetNetworkCredential().Password
            } 

            Write-Verbose -Message "Converting the Data into a JSON object to be used in the body of the RestMethod."
            $Body = ConvertTo-Json (@{ data = $data })

            
            $uri = ($Global:NimbleApiUrls.GetToken -f $this.NimbleArrayUrl)
            Write-Verbose -Message "Uri: $Uri"
            
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()

            Write-Verbose -Message "Invoking the RestMethod"
            $this.TokenObject = (Invoke-RestMethod -Uri $uri -Method Post -Body $Body -ErrorAction Stop).Data

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

            return $true
        }
        catch {
            Write-Error -Exception $_.Exception
            return $false
        }
    }

    [Bool] IsTokenExpired() {
        if([DateTime]::UtcNow -gt $this.TokenExpirationTime){
            return $true
        }
        else {
            return $false
        }
    }
}