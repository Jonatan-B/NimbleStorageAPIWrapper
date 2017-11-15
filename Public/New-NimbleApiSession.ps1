function New-NimbleApiSession {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Url of the Nimble Array
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-NetConnection -ComputerName $_ -Port 5392 -InformationLevel Quiet  })]
        [String]
        $ArrayUrl, 
        # Username to use to connect to the Nimble Array
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [String]
        $Username,
        # Password to use to connect to the Nimble Array
        [Parameter(Mandatory, Position=2, ValueFromPipelineByPropertyName)]
        [SecureString]
        $Password
    )
    begin {
        Write-Verbose -Message "Ensuring that the [NimbleApiSession] type has been loaded."
        try { [NimbleApiSession] | Out-Null }catch { throw "This module requires the use of the IgnoreSSLWarning Type found in the types_.ps1 file. Import the module or add this type manually and try again."}        

        Write-Verbose -Message "No errors detected. Continuing to create the PSCredential object."
        $Credentials = New-Object -TypeName PSCredential -ArgumentList $Username, $Password
    }
    process {
        
        if($Global:NimbleSession."Session__$ArrayUrl"){
            if(($Global:NimbleSession."Session__$ArrayUrl".IsConnected -eq $false) -or ($Global:NimbleSession."Session__$ArrayUrl".IsTokenExpired() -eq $true)){

                Write-Verbose -Message "A session already existed but is not longer connected, or has expired. Creating a new session."
                $Global:NimbleSession.Remove("Session__$ArrayUrl")
            }
            else {
                Write-Verbose "A valid session for this array has already been created. No need to create a new one."
                return $Global:NimbleSession."Session__$ArrayUrl"
            }
        }
        
        if($PSCmdlet.ShouldProcess($username, "Create new Nimble Api session.")) {

            Write-Verbose -Message "Creating the NimbleApiSession on $arrayUrl with $username."
            $Session = [NimbleApiSession]::new($Credentials, $ArrayUrl)
            
            if($Session){

                Write-Verbose -Message "Session has been created. Ensuring that it is properly connected."
                if($Session.IsConnected){

                    Write-Verbose -Message "Session Is connected. Adding the session to the global hashtable to be used with other cmdlets."
                    $Global:NimbleSession.Add("Session__$ArrayUrl", $Session)
                }
                else {

                    Write-Verbose -Message "Session is Not connected. Printing the returned Object to see what was returned."
                    $Session
                }
            }
            else {
                Write-Error -Message "No object was returned by the [NimbleApiSession] constructor." -ErrorAction Stop
            }
        }
    }
}