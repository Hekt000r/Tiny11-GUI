function Get-Tiny11ImageInfo {
    param (
        [string]$IsoPath
    )
    
    $isMounted = $false
    $driveLetter = ""

    try {
        if (Test-Path $IsoPath -PathType Leaf) {
            $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            $isMounted = $true
        }
        else {
            $driveLetter = $IsoPath.TrimEnd(':').TrimEnd('\')
        }

        if (-not $driveLetter) { throw "Could not determine drive letter for $IsoPath" }
        
        $fullPath = $driveLetter + ":"
        $installWim = Join-Path $fullPath "sources\install.wim"
        $installEsd = Join-Path $fullPath "sources\install.esd"

        $images = $null
        if (Test-Path $installWim) {
            $images = Get-WindowsImage -ImagePath $installWim
        }
        elseif (Test-Path $installEsd) {
            $images = Get-WindowsImage -ImagePath $installEsd
        }
        else {
            throw "Could not find install.wim or install.esd on $fullPath"
        }

        # Return object with drive letter metadata so caller can unmount
        return @{
            Images = $images
            DriveLetter = $driveLetter
            Mounted = $isMounted
        }
    }
    catch {
        if ($isMounted) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue }
        throw $_
    }
}

function Build-Tiny11 {
    param (
        [string]$IsoPath,
        [string]$ScratchDrive,
        [int]$ImageIndex,
        [bool]$RemoveEdge,
        [bool]$DisableTelemetry,
        [ScriptBlock]$OnProgress
    )

    process {
        if (-not $IsoPath) { throw "ISO Path is required. Please select a Windows ISO or drive." }
        if (-not $ScratchDrive) { throw "Scratch Drive is required. Please specify a drive letter (e.g., 'C')." }

        # Initialize variables early for safe cleanup in catch block
        $isMounted = $false
        $mountDir = $null
        $workingDir = $null
        $DriveLetter = $null
        try {
            #---------[ Internal Functions ]---------#
            function Set-RegistryValue {
                param ([string]$path, [string]$name, [string]$type, [string]$value)
                & 'reg' 'add' $path '/v' $name '/t' $type '/d' $value '/f' | Out-Null
            }

            function Remove-RegistryValue {
                param ([string]$path)
                & 'reg' 'delete' $path '/f' | Out-Null
            }

            #---------[ ISO/Drive Handling ]---------#
            $OnProgress.Invoke("Identifying ISO source...", 2)
            if (Test-Path -Path $IsoPath -PathType Leaf) {
                $OnProgress.Invoke("Mounting ISO image...", 3)
                $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
                
                # Robustly get drive letter
                $DriveLetter = ($mountResult | Get-Volume).DriveLetter
                if (-not $DriveLetter) {
                    $OnProgress.Invoke("Waiting for drive letter...", 4)
                    Start-Sleep -Seconds 2
                    $DriveLetter = (Get-DiskImage -ImagePath $IsoPath | Get-Volume).DriveLetter
                }
                
                if (-not $DriveLetter) { throw "Could not determine drive letter for mounted ISO: $IsoPath" }
                $isMounted = $true
            } else {
                $DriveLetter = $IsoPath.TrimEnd(':').TrimEnd('\')
            }
            
            $OnProgress.Invoke("Setting up paths for drive $($DriveLetter)...", 5)
            $srcPath = $DriveLetter + ":"
            
            $ScratchDisk = $ScratchDrive
            if ($ScratchDisk -match '^[c-zC-Z]$') { $ScratchDisk = $ScratchDisk + ":" }
            
            $workingDir = Join-Path -Path $ScratchDisk -ChildPath "tiny11"
            $mountDir = Join-Path -Path $ScratchDisk -ChildPath "scratchdir"
            
            # Clean up previous attempts
            if ($workingDir -and (Test-Path -Path $workingDir)) { Remove-Item -Path $workingDir -Recurse -Force -ErrorAction SilentlyContinue }
            if ($mountDir -and (Test-Path -Path $mountDir)) { Remove-Item -Path $mountDir -Recurse -Force -ErrorAction SilentlyContinue }

            New-Item -ItemType Directory -Force -Path (Join-Path -Path $workingDir -ChildPath "sources") | Out-Null
            New-Item -ItemType Directory -Force -Path $mountDir | Out-Null

            #---------[ WIM/ESD Handling ]---------#
            $OnProgress.Invoke("Checking installation files...", 5)
            $srcWim = Join-Path $srcPath "sources\install.wim"
            $srcEsd = Join-Path $srcPath "sources\install.esd"
            $destWim = Join-Path $workingDir "sources\install.wim"

            if (Test-Path $srcWim) {
                $OnProgress.Invoke("Copying Windows image...", 10)
                Copy-Item -Path "$srcPath\*" -Destination "$workingDir" -Recurse -Force | Out-Null
            }
            elseif (Test-Path $srcEsd) {
                $OnProgress.Invoke("Converting install.esd to install.wim...", 10)
                $files = Get-ChildItem -Path "$srcPath\*" -Exclude "install.esd"
                foreach ($file in $files) {
                    Copy-Item -Path $file.FullName -Destination "$workingDir" -Recurse -Force | Out-Null
                }
                Export-WindowsImage -SourceImagePath $srcEsd -SourceIndex $ImageIndex -DestinationImagePath $destWim -Compressiontype Maximum -CheckIntegrity
            }
            else {
                throw "Could not find install.wim or install.esd"
            }

            #---------[ Mounting ]---------#
            $OnProgress.Invoke("Mounting Windows image...", 20)
            $adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
            $adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])
            
            & takeown "/F" $destWim | Out-Null
            & icacls $destWim "/grant" "$($adminGroup.Value):(F)" | Out-Null
            Set-ItemProperty -Path $destWim -Name IsReadOnly -Value $false | Out-Null

            Mount-WindowsImage -ImagePath $destWim -Index $ImageIndex -Path $mountDir

            #---------[ Removal ]---------#
            $OnProgress.Invoke("Removing Appx packages...", 30)
            
            $packagePrefixes = 'AppUp.IntelManagementandSecurityStatus','Clipchamp.Clipchamp','DolbyLaboratories.DolbyAccess',
            'DolbyLaboratories.DolbyDigitalPlusDecoderOEM','Microsoft.BingNews','Microsoft.BingSearch',
            'Microsoft.BingWeather','Microsoft.Copilot','Microsoft.Windows.CrossDevice','Microsoft.GamingApp',
            'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Microsoft3DViewer','Microsoft.MicrosoftOfficeHub',
            'Microsoft.MicrosoftSolitaireCollection','Microsoft.MicrosoftStickyNotes','Microsoft.MixedReality.Portal',
            'Microsoft.MSPaint','Microsoft.Office.OneNote','Microsoft.OfficePushNotificationUtility',
            'Microsoft.OutlookForWindows','Microsoft.Paint','Microsoft.People','Microsoft.PowerAutomateDesktop',
            'Microsoft.SkypeApp','Microsoft.StartExperiencesApp','Microsoft.Todos','Microsoft.Wallet',
            'Microsoft.Windows.DevHome','Microsoft.Windows.Copilot','Microsoft.Windows.Teams','Microsoft.WindowsAlarms',
            'Microsoft.WindowsCamera','microsoft.windowscommunicationsapps','Microsoft.WindowsFeedbackHub',
            'Microsoft.WindowsMaps','Microsoft.WindowsSoundRecorder','Microsoft.WindowsTerminal','Microsoft.Xbox.TCUI',
            'Microsoft.XboxApp','Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider',
            'Microsoft.XboxSpeechToTextOverlay','Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
            'MicrosoftCorporationII.MicrosoftFamily','MicrosoftCorporationII.QuickAssist','MSTeams','MicrosoftTeams',
            'Microsoft.WindowsTerminal','Microsoft.549981C3F5F10'

            $packages = Get-AppxProvisionedPackage -Path $mountDir
            foreach ($pkg in $packages) {
                foreach ($prefix in $packagePrefixes) {
                    if ($pkg.PackageName -like "*$prefix*") {
                        Remove-AppxProvisionedPackage -Path $mountDir -PackageName $pkg.PackageName | Out-Null
                        break
                    }
                }
            }

            if ($RemoveEdge) {
                $OnProgress.Invoke("Removing Edge...", 40)
                $edgePaths = @(
                    "Program Files (x86)\Microsoft\Edge",
                    "Program Files (x86)\Microsoft\EdgeUpdate",
                    "Program Files (x86)\Microsoft\EdgeCore",
                    "Windows\System32\Microsoft-Edge-Webview"
                )
                foreach ($p in $edgePaths) {
                    $fullPath = Join-Path $mountDir $p
                    if (Test-Path $fullPath) {
                        & takeown /f $fullPath /r /a | Out-Null
                        & icacls $fullPath /grant "$($adminGroup.Value):(F)" /T /C /Q | Out-Null
                        Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            $OnProgress.Invoke("Removing OneDrive...", 45)
            $oneDrivePath = Join-Path $mountDir "Windows\System32\OneDriveSetup.exe"
            if (Test-Path $oneDrivePath) {
                & takeown /f $oneDrivePath /a | Out-Null
                & icacls $oneDrivePath /grant "$($adminGroup.Value):(F)" /Q | Out-Null
                Remove-Item $oneDrivePath -Force -ErrorAction SilentlyContinue | Out-Null
            }

            #---------[ Registry Tweaks ]---------#
            $OnProgress.Invoke("Applying registry tweaks...", 50)
            $regPaths = @{
                "COMPONENTS" = Join-Path $mountDir "Windows\System32\config\COMPONENTS"
                "DEFAULT"    = Join-Path $mountDir "Windows\System32\config\default"
                "NTUSER"     = Join-Path $mountDir "Users\Default\ntuser.dat"
                "SOFTWARE"   = Join-Path $mountDir "Windows\System32\config\SOFTWARE"
                "SYSTEM"     = Join-Path $mountDir "Windows\System32\config\SYSTEM"
            }

            foreach ($key in $regPaths.Keys) {
                & 'reg' 'load' "HKLM\z$key" $regPaths[$key] | Out-Null
            }

            Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
            Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
            Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
            Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassCPUCheck' 'REG_DWORD' '1'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassRAMCheck' 'REG_DWORD' '1'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassSecureBootCheck' 'REG_DWORD' '1'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassStorageCheck' 'REG_DWORD' '1'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassTPMCheck' 'REG_DWORD' '1'
            Set-RegistryValue 'HKLM\zSYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 'REG_DWORD' '1'

            # Disable Telemetry
            if ($DisableTelemetry) {
                Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 'REG_DWORD' '0'
                Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'REG_DWORD' '0'
            }

            foreach ($key in $regPaths.Keys) {
                & 'reg' 'unload' "HKLM\z$key" | Out-Null
            }

            #---------[ Cleanup & Unmount ]---------#
            $OnProgress.Invoke("Cleaning up image...", 70)
            & dism /Image:$mountDir /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

            $OnProgress.Invoke("Unmounting Windows image...", 80)
            Dismount-WindowsImage -Path $mountDir -Save | Out-Null

            #---------[ Export ]---------#
            $OnProgress.Invoke("Exporting optimized image...", 90)
            $destWim2 = Join-Path -Path $workingDir -ChildPath "sources\install2.wim"
            
            # Use Dism.exe with absolute paths
            & dism.exe /Export-Image /SourceImageFile:$destWim /SourceIndex:$ImageIndex /DestinationImageFile:$destWim2 /Compress:fast | Out-Null
            
            if (Test-Path -Path $destWim2) {
                if (Test-Path -Path $destWim) { Remove-Item -Path $destWim -Force -ErrorAction SilentlyContinue | Out-Null }
                Rename-Item -Path $destWim2 -NewName "install.wim" -Force | Out-Null
            } else {
                throw "Export-Image failed: $destWim2 was not created."
            }

            #---------[ ISO Creation ]---------#
            $OnProgress.Invoke("Creating ISO image...", 95)
            
            # Locate or download autounattend.xml
            $autounattendFile = Join-Path -Path $PSScriptRoot -ChildPath "autounattend.xml"
            if (-not (Test-Path -Path $autounattendFile)) {
                # Check parent folder (root)
                $parentFolder = Split-Path -Path $PSScriptRoot -Parent
                $autounattendFile = Join-Path -Path $parentFolder -ChildPath "autounattend.xml"
            }
            
            if (-not (Test-Path -Path $autounattendFile)) {
                $OnProgress.Invoke("Downloading autounattend.xml...", 96)
                $xmlUrl = "https://raw.githubusercontent.com/ntdevlabs/tiny11builder/refs/heads/main/autounattend.xml"
                $autounattendFile = Join-Path -Path $PSScriptRoot -ChildPath "autounattend.xml"
                Invoke-WebRequest -Uri $xmlUrl -OutFile $autounattendFile -ErrorAction Stop
            }
            
            Copy-Item -Path $autounattendFile -Destination (Join-Path -Path $workingDir -ChildPath "autounattend.xml") -Force | Out-Null

            # Locate or download oscdimg.exe
            $hostArch = $Env:PROCESSOR_ARCHITECTURE
            if ($hostArch -eq "AMD64") { $hostArch = "x64" }
            
            $adkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$hostArch\Oscdimg\oscdimg.exe"
            $localOscdimg = Join-Path -Path $PSScriptRoot -ChildPath "oscdimg.exe"
            $oscdimgExe = $null

            if (Test-Path -Path $adkPath) {
                $oscdimgExe = $adkPath
            } elseif (Test-Path -Path $localOscdimg) {
                $oscdimgExe = $localOscdimg
            } else {
                $OnProgress.Invoke("Downloading oscdimg.exe...", 97)
                $url = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"
                Invoke-WebRequest -Uri $url -OutFile $localOscdimg -ErrorAction Stop
                $oscdimgExe = $localOscdimg
            }

            # Output ISO to project root (parent of core)
            $projectRoot = Split-Path -Path $PSScriptRoot -Parent
            $isoOutput = Join-Path -Path $projectRoot -ChildPath "tiny11.iso"
            $bootData = "2#p0,e,b$($workingDir)\boot\etfsboot.com#pEF,e,b$($workingDir)\efi\microsoft\boot\efisys.bin"
            
            $OnProgress.Invoke("Running oscdimg...", 98)
            & "$oscdimgExe" '-m' '-o' '-u2' '-udfver102' "-bootdata:$bootData" "$workingDir" "$isoOutput" | Out-Null

            # Cleanup ISO mount if we did it
            if ($isMounted -and $IsoPath) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null }

            $OnProgress.Invoke("Build complete! ISO saved to root folder.", 100)
        }
        catch {
            if ($isMounted -and $IsoPath) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null }
            if ($mountDir -and (Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $mountDir })) {
                # Attempt to unmount, but don't let it mask the original error
                try { Dismount-WindowsImage -Path $mountDir -Discard -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
            
            # Final cleanup of locked folders can be tricky, we'll leave them if they fail to delete here
            # to avoid masking the real error. The user can manually delete them or run the script again.
            throw $_
        }
    }
}

Export-ModuleMember -Function Build-Tiny11, Get-Tiny11ImageInfo
