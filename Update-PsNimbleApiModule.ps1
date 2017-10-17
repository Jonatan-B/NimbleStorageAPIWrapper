function Update-PsNimbleApiModule {
    [CmdletBinding()]
    param(
        # The build number of the module. If a number 1 is provided it'll attempt to add it to the current Revision Number.
        # Otherwise it'll replace it. If Build Number is 1 and Revision Number is -1 then it'll simply use 1.
        [Parameter( Mandatory, Position = 0 )]
        [int]
        $BuildNumber = 1,
        # Where should the module be installed? 
        # User: $home\Documents\WindowsPowerShell\Modules
        # Machine: $env:ProgramFiles\WindowsPowerShell\Modules (Default)
        [Parameter( Position = 1)]
        [ValidateSet("User","Machine")]
        [String]
        $InstallationType = "User"
    ) 

    $NimbleApiFunctions = @()
    $NimbleApiFunctions += Get-ChildItem .\Private\*.ps1 -Recurse
    $NimbleApiFunctions += Get-ChildItem .\Public\*.ps1 -Recurse

    if($InstallationType -eq "User"){
        $buildDest =  "$($home)\Documents\WindowsPowerShell\Modules"

        if(!(Test-Path $buildDest)){
            if(($env:PSModulePath -split ";") -contains $buildDest){
                try {
                    New-Item -Path "$($home)\Documents" -Name WindowsPowerShell -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
                catch {
                    $_
                }

                try {
                    New-Item -Path "$($home)\Documents\WindowsPowerShell" -Name Modules -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
                catch {
                    $_
                }
            }
            else {
                throw "The default user location $($buildDest) is not configured in the PSModulePath variable. Please check your settings and try again."
            }
        }
    }
    else {
        if(!([System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)){
            throw "Administrator access is required to install the module at the machine level." 
        }

        $buildDest =  "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }
    
    if(!(Test-Path $buildDest)){
        throw "Unable to find the default Modules folder."
    }
    else {
        $buildDest = Join-Path -Path $buildDest -ChildPath "PsNimbleApiModule"
    }

    if ( !(Test-Path -Path $buildDest) ) {
        Write-Verbose -Message "Unable to find $buildDest. Creating the path."
        New-Item -Path $buildDest -ItemType Directory -ErrorAction Stop | Out-Null
    }
    
    if ( !(Test-Path -Path "$buildDest\Private") ) {
        Write-Verbose -Message "Unable to find $buildDest\Private. Creating the path."
        New-Item -Path $buildDest -Name "Private" -ItemType Directory -ErrorAction Stop | Out-Null
    }

    Write-Verbose -Message "Copying the necessary script files to $buildDest\Private."
    Copy-Item -Path $((Test-ModuleManifest .\PsNimbleApi.psd1 -ErrorAction Stop).Scripts) -Destination $buildDest\Private -Force -ErrorAction Stop

    Write-Verbose -Message "Copying the PowerShell Data file to $buildDest."
    Copy-Item -Path ".\PsNimbleApi.psd1" -Destination $buildDest -Force -ErrorAction Stop

    $versionInfo = (Test-ModuleManifest -Path ".\PsNimbleApi.psd1" -ErrorAction Stop).version
    Write-Verbose "Current module version is $($versionInfo.ToString())."

    if($BuildNumber -eq 1){
        if($versionInfo.Revision -ne -1){
            $BuildNumber = $versionInfo.Revision++
        }         
    }

    $bumpVersion = "$($versionInfo.Major).$($versionInfo.Minor).$($versionInfo.Build).$BuildNumber"
    Write-Verbose "Incrementing module to version $bumpVersion"

    $manifestProperties = @{
        Path = Join-Path $buildDest "PsNimbleApi.psd1"
        ModuleVersion = $bumpVersion
        FunctionsToExport = $NimbleApiFunctions.BaseName
        AliasesToExport = "*"
    }

    Write-Verbose -Message "Updating the Manifest to $bumpVersion, and adding the exported functions."
    Update-ModuleManifest @manifestProperties 

    Write-Verbose -Message "Writing the functions in the .psm1 file."
    $NimbleApiFunctions | Where-Object { $_.Name -ne "types_.ps1" } | Get-Content | Out-File "$buildDest\PsNimbleApi.psm1" -ErrorAction Stop
}