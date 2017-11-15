function Expand-NimbleVolume {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        # Query for a specific Volume ID
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $VolumeId,
        # Array that you want to connect to.
        [Parameter(Position=1, Mandatory, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl,
        # The size fo the volume that will be created
        [Parameter(Position=2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidatePattern("^\d+(MB|GB|TB)$")]
        [String]
        $ExpandSize
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
        
        $VolumeSizeInMBLimits = @{
            512   = "2TB"/1MB
            1024  = "4TB"/1MB
            2048  = "8TB"/1MB
            4096  = "16TB"/1MB
            8192  = "32TB"/1MB
            16384 = "64TB"/1MB
            32768 = "128TB"/1MB
            65536 = "256TB"/1MB
        }

        $uri = ($Global:NimbleApiUrls.GetVolumeById -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl, $VolumeId)
    }
    process {
        Write-Verbose -Message "Gathering the volume's current configuration."
        try {
            $NimbleVolume = Get-NimbleVolume -VolumeId $VolumeId -ArrayUrl $ArrayUrl
        }
        catch {
            throw [Exception]::new("Unable to get information for a volume with id $($VolumeId) on array $($ArrayUrl). Error: $($_)")
        }

        if($NimbleVolume.owned_by_group -ne $ArrayUrl){
           throw [Exception]::new("The volume is not owned by the array and cannot be modified.")
        }
        
        $VolumeSizeInMB = $NimbleVolume.Size
        Write-Verbose -Message "Current Drive size: $($NimbleVolume.Size)MB"
        
        $ExpandSizeInMB = $ExpandSize/1MB
        Write-Verbose -Message "Increasing size by $($ExpandSizeInMB)MB"

        $NewVolumeSize = $VolumeSizeInMB + $ExpandSizeInMB
        Write-Verbose -Message "New Volume Size: $($NewVolumeSize)MB"

        $VolumeBlockSize = $NimbleVolume.block_size
        if($VolumeSizeLimits.$VolumeBlockSize -lt $NewVolumeSize){
            $ConfirmPreference = "Low"
            if(!($PSCmdlet.ShouldContinue("Expanding the volume to $([Math]::Round($("$($NewVolumeSize)MB"/1TB),2))TB will exceed the max size of $("$($VolumeSizeInMBLimits.$VolumeBlockSize)MB"/1TB)TB on block size $($VolumeBlockSize). Continue?"," Max size exceeded."))){
                Write-Warning -Message "Aborted. The cmdlet has been interrupted as the requested changes would push the volume size past the max size limit."

                return
            }
            else {
                $ConfirmPreference = "High"
            }
        }

        $data = @{
            size = $NewVolumeSize
        }

        $Body = ConvertTo-Json (@{ data = $data })

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
        
        if($PSCmdlet.ShouldProcess($VolumeId, "Expand volume to $($NewVolumeSize)MB.")) {
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            try {
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