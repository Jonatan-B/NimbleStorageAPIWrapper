function Push-PsNimbleApiModule {
    <#
    .SYNOPSIS
    Used for CD distribution of the PsNimbleApi module across terminal servers.

    .PARAMETER ComputerName
    The target computer to push PsNimbleApi to.

    .PARAMETER NoNugetCheck
    This will bypass the check for Nuget as this fails on systems without Internet access.
    #>

    [CmdletBinding()]

    param(
        [Parameter( Mandatory, Position = 0, ValueFromPipeline )]
        [string[]]$ComputerName,

        [switch]$NoNugetCheck
    )

    Begin {
        $errors = $false
    }

    Process {
        foreach ( $comp in $ComputerName ) {

            Write-Verbose "Connecting to $comp"
            $session = $null
            try {
                $session = New-PSSession -ComputerName $comp -ErrorAction Stop
            }
            catch {
                $errors = $true
                Write-Error "Failed to establish a connection to $comp"
                Continue
            }

            if ( !($NoNugetCheck.IsPresent)) {
                Write-Verbose "Making sure Nuget is available"
                Invoke-Command -Session $session -ErrorAction Stop -Verbose {
                    try {
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-Error "Failed to confirm Nuget availability."
                        Continue
                    }
                }
            }
            
            # Check for the adiPsGalleryRepo and add it if missing.
            Write-Verbose "Checking for adiPsGallery repo registration"
            Invoke-Command -Session $session -ErrorAction Stop -Verbose {
                $VerbosePreference = "Continue"
                try {
                    Write-Verbose "Importing PackageManagement PS module"
                    Import-Module PackageManagement -Verbose:$false -ErrorAction Stop
                    Write-Verbose "Importing PowershellGet PS module"
                    Import-Module PowerShellGet -Verbose:$false -ErrorAction Stop
                    $repoExists = Get-PSRepository -Name adiPsGallery -ErrorAction SilentlyContinue

                    if ( !($repoExists) ) {
                        Write-Verbose "AdiPsGallery not registered.  Registering now."
                        
                        $params = @{
                            Name            = "AdiPsGallery"
                            SourceLocation  = "http://adiNuget.us.ae.ge.com/nuget/adipsgallery"
                            PublishLocation = "http://adiNuget.us.ae.ge.com/nuget/adipsgallery/packages"
                            InstallationPolicy        = "Trusted"
                            PackageManagementprovider = "Nuget"
                            Verbose         = $True
                            ErrorAction    = "Stop"
                        }
                        Register-PsRepository @params
                    }
                    else {
                        Write-Verbose "AdiPsGallery is already registered."
                    }
                } 
                catch {
                    $errors = $true
                    Write-Error "Remote error encountered while registering AdiPsGallery."
                    Continue
                }
            }

            Write-Verbose "Getting PsNimbleApi via Install-Module"
            try {
                Invoke-Command -Session $session -ErrorAction Stop -Verbose {
                    Install-Module -Name PsNimbleApi -Repository adiPsGallery -Force -Scope AllUsers -Verbose -ErrorAction Stop
                }
            }
            catch {
                $errors = $true
                Write-Error "Error installing PsNimbleApi on $comp"
                Continue
            }
            
            Write-Verbose "Removing old versions and copying to 32bit module path"
            try {
                Invoke-Command -Session $session -ErrorAction Stop -Verbose {
                    $destPartialPath = "WindowsPowershell\modules\PsNimbleApi\"
                    $module64Path = Join-Path "c:\program files" $destPartialPath
                    # this sorts the module versions by the creation time and removes all but the latest one
                    $existingVersions = Get-ChildItem -Path $module64Path | Sort-Object -Property "CreationTime"
                    for($i = 0; $i -lt ($existingVersions.count - 1); $i++) {
                        Remove-Item -Path $existingVersions[$i].FullName -Recurse -Force
                    }

                    $module32Path = Join-Path "c:\program files (x86)" $destPartialPath
                    Remove-Item -Path $module32Path -Recurse -Force
                    Copy-Item -Path $module64Path -Destination $module32Path -Force -Recurse -ErrorAction Stop
                }
            }
            catch {
                Write-Error "Failed during cleanup and copy to 32bit module path."
                Continue
            }
            
        }
    }

    End {
        if ( $errors ) {
            throw "Errors deploying.  Review log for problem deployment."
        }
    }
}
