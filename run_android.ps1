$ErrorActionPreference = 'Stop'

$avdName = 'Pixel_7'
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adbPath = Join-Path $androidSdk 'platform-tools\adb.exe'
$emulatorPath = Join-Path $androidSdk 'emulator\emulator.exe'
$avdRoot = Join-Path $env:USERPROFILE '.android\avd'
$avdIniPath = Join-Path $avdRoot "$avdName.ini"
$avdProfilePath = Join-Path $avdRoot "$avdName.avd"

function Get-ConnectedAndroidDevice {
    $deviceLines = & $adbPath devices

    foreach ($deviceLine in $deviceLines) {
        if ($deviceLine -match '^(\S+)\s+device$') {
            return $Matches[1]
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "Android Debug Bridge was not found at $adbPath"
}

if (-not (Test-Path -LiteralPath $emulatorPath)) {
    throw "Android Emulator was not found at $emulatorPath"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on Path. Expected C:\dev\flutter\bin to be on the user Path.'
}

Push-Location $PSScriptRoot

try {
    $deviceId = Get-ConnectedAndroidDevice

    if (-not $deviceId) {
        $availableAvds = @(& $emulatorPath -list-avds)
        if ($avdName -notin $availableAvds -and -not (Test-Path -LiteralPath $avdIniPath)) {
            throw "Android emulator '$avdName' was not found. Available emulators: $($availableAvds -join ', ')"
        }

        $runningEmulator = Get-Process emulator, qemu-system-x86_64 -ErrorAction SilentlyContinue
        if (-not $runningEmulator -and (Test-Path -LiteralPath $avdProfilePath)) {
            $staleLockPaths = @(
                (Join-Path $avdProfilePath 'multiinstance.lock'),
                (Join-Path $avdProfilePath 'hardware-qemu.ini.lock')
            )

            foreach ($staleLockPath in $staleLockPaths) {
                if (Test-Path -LiteralPath $staleLockPath) {
                    Remove-Item -LiteralPath $staleLockPath -Recurse -Force
                }
            }
        }

        Write-Host "Starting Android emulator $avdName..."
        Start-Process -FilePath $emulatorPath -ArgumentList '-avd', $avdName

        $deviceDeadline = (Get-Date).AddMinutes(2)
        do {
            Start-Sleep -Seconds 2
            $deviceId = Get-ConnectedAndroidDevice
        } until ($deviceId -or (Get-Date) -ge $deviceDeadline)

        if (-not $deviceId) {
            throw "The $avdName emulator did not connect within two minutes."
        }
    }

    Write-Host "Waiting for Android on $deviceId..."
    $bootDeadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 2
        $bootCompleted = (& $adbPath -s $deviceId shell getprop sys.boot_completed 2>$null).Trim()
    } until ($bootCompleted -eq '1' -or (Get-Date) -ge $bootDeadline)

    if ($bootCompleted -ne '1') {
        throw 'Android did not finish booting within three minutes.'
    }

    Write-Host 'Getting Flutter packages...'
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }

    Write-Host "Running PikZen on $deviceId..."
    & flutter run -d $deviceId
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter run failed.'
    }
}
finally {
    Pop-Location
}
