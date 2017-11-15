function New-NimbleVolume {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Volume Name
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [String]
        $Name,
        # The size fo the volume that will be created
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidatePattern("^\d+(MB|GB|TB)$")]
        [String]
        $VolumeSize,
        # Array where the new volume will be created
        [Parameter(Mandatory, Position=3, ValueFromPipelineByPropertyName)]
        [String]
        $ArrayUrl, 
        # Description of the new volume.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateLength(0,255)]
        [String]
        $Description = "Created by $($env:USERNAME) with the PsNimbleApi module.", 
        # Initiator ID that will be granted access to this volume.
        [Parameter(ValueFromPipelineByPropertyName)]
        [String[]]
        $InitiatorGroupIds,
        # Performance policy id that will be applied to the new volume
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $PerformancePolicyId,
        # Id of a Volume Collection where the new Volume will be added to.
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]
        $VolumeCollectionId,
        # MultiInitiator access
        [Bool]
        $MultiInitiatorAccess=$true,
        # Blocksize of the new Volume
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet(512, 1024, 2048, 4096, 8192, 16384, 32768, 65536)]
        [UInt64]
        $BlockSize = 4096,
        # Should the new volume be offline? 
        [Switch]
        $Offline,
        # Should the new drive have dedup enabled?
        [Switch]
        $EnableDedup,
        # Should the Volume be pinned to the cache for higher perfoamance?
        [Switch]
        $PinToCache
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

        Write-Verbose -Message "Getting the list of volumes on the Array to check if the volume name already exists."
        $NimbleVolumes = Get-NimbleVolume -List -ArrayUrl $ArrayUrl
        if($NimbleVolumes.Name -contains $Name){
            throw [Exception]::new("The volume $($name) already exists on $($arrayUrl) and cannot be created again.")
        }

        $VolumeSizeInMB = $VolumeSize/1MB

        $data = @{
            "name" = $Name
            "size" = [Int]$VolumeSizeInMB
            "description" = $Description
            "multi_initiator" = $MultiInitiatorAccess
            "block_size" = $BlockSize
        }

        if($PerformancePolicyId){
            try {
                Get-NimblePerformancePolicy -PerformancePolicyId $PerformancePolicyId -ArrayUrl $ArrayUrl -ErrorAction Stop | Out-Null
                $data.Add("perfpolicy_id", $PerformancePolicyId)
            }
            catch {
                throw [Exception]::new("Unable to find the Performance Policy with ID $($PerformancePolicyId) on $($ArrayUrl). Error: $($_)")
            }
        }

        if($Offline.IsPresent){
            $data.Add("online", $false)
        }

        if($EnableDedup.IsPresent){
            $data.Add("dedupe_enabled", $true)
        }

        if($PinToCache.IsPresent){
            $data.Add("cache_pinned", $true)
        }

        $Body = ConvertTo-Json (@{ data = $data })

        $uri = ($Global:NimbleApiUrls.GetVolumesOverview -f $Global:NimbleSession."Session__$ArrayUrl".NimbleArrayUrl)
    }
    process {
        Write-Verbose -Message "Invoking Method POST on $uri with token: $($Global:NimbleSession."Session__$ArrayUrl".SessionHeader.'X-Auth-Token')."
        Write-Verbose -Message "Data passed to the API:"
        $data.Keys  | ForEach-Object { Write-Verbose -Message "$($_) = $($Data.$_)" }
        Write-Verbose -Message ""

        $RestMethodParams = @{
            Method = "Post"
            Uri = $uri
            Headers = $Global:NimbleSession."Session__$ArrayUrl".SessionHeader
            Body = $Body
        }
        
        if($PSCmdlet.ShouldProcess($ArrayUrl, "Create new volume $($Name) with Size $($VolumeSize)$SizeUnit.")) {
            Write-Verbose -Message "Configuring the Certificate Validation Callback to ignore SSL Warnings."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [IgnoreSSLWarning]::GetDelegate()
            
            try{
                $NewVolumeInformation = (Invoke-RestMethod @RestMethodParams -ErrorAction Stop).Data
            }
            catch {
                $ErrorResults = Read-RestMethodError -ResultStream ($_.Exception.Response.GetResponseStream())   
                Write-Error -Message ($ErrorResults.Messages.Text -join " ") -ErrorId ($ErrorResults.Messages.Code -join ", ") -ErrorAction Stop
            }

            Write-Verbose -Message "Checking that the volume information was returned by the API."
            if($NewVolumeInformation){

                Write-Verbose -Message "Checking if the VolumeCollectionId variable was provided. If so then we add the new volume to the collection."
                if($VolumeCollectionId) {
                    try {
                        Set-NimbleVolume -VolumeId $NewVolumeInformation.id -ArrayUrl $ArrayUrl -VolumeCollectionId $VolumeCollectionId -ErrorAction Stop
                    }
                    catch {
                        Write-Error -Message "Failed to add the volume to the Volume collection with id $($VolumeCollectionId). Error: $($_.Exception.Message)"
                    }
                }

                Write-Verbose -Message "Checking if the InitiatorGroupId variable was provided. If so then we add the new volume to the initiator group."
                if($InitiatorGroupIds) {
                    try{
                        foreach($Id in $InitiatorGroupIds){
                            try {
                                New-NimbleAccessControlRecord -VolumeId $NewVolumeInformation.id -InitiatorGroupId $Id -ArrayUrl $ArrayUrl -ACRType both -ErrorAction Stop | Out-Null
                            }
                            catch {
                                Write-Error -Message "Failed to create a ACR for Id $($Id). Error: $($_.Exception.Message)"
                                continue
                            }
                        }
                    }
                    catch {
                        Write-Error -Message "Failed to add the volume to the Initiator Group with Id $($InitiatorGroupId). Error: $($_.Exception.Message)"
                    }
                }

                Write-Verbose -Message "Perform an API call to get the volume settings after the changes have been done and return that."
                Get-NimbleVolume -VolumeId $NewVolumeInformation.Id -ArrayUrl $ArrayUrl
            }
            else {
                throw [Exception]::new("The RestMethod did not create an error but no object was returned. Check the Nimble Array and ensure if it was created properly")
            }

            Write-Verbose -Message "Removing the Ignore SSL Warnings setting."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }       
    }
}