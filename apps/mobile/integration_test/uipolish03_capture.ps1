param(
  [Parameter(Mandatory = $true)][string]$AdbPath,
  [Parameter(Mandatory = $true)][string]$LogPath,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [ValidatePattern('^emulator-[0-9]+$')][string]$Serial = 'emulator-5584',
  [ValidateSet('before', 'after')][string]$Phase = 'after'
)

$ErrorActionPreference = 'Stop'
$avdName = @(& $AdbPath -s $Serial emu avd name)
if ($LASTEXITCODE -ne 0 -or $avdName[0] -ne 'PLANETS_UIPOLISH_QA') {
  throw "Expected task-owned PLANETS_UIPOLISH_QA at $Serial."
}
$captureDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($captureDirectory) | Out-Null
$captured = [Collections.Generic.HashSet[string]]::new()
$deadline = [DateTime]::UtcNow.AddMinutes(20)
$pattern = 'UIPOLISH03_CAPTURE (uipolish03-' + $Phase + '-(?:360-1x|320-2x)-[a-z-]+) (/data/(?:user/0|data)/community\.planets\.app/(?:cache|code_cache)/[a-z0-9.-]+\.ack)'
while ([DateTime]::UtcNow -lt $deadline -and $captured.Count -lt 14) {
  if (Test-Path -LiteralPath $LogPath) {
    if (Select-String -LiteralPath $LogPath -Pattern 'Some tests failed|^Unhandled exception:' -Quiet) {
      throw "Native test run failed. See $LogPath."
    }
    $markers = Select-String -LiteralPath $LogPath -Pattern $pattern -AllMatches
    foreach ($marker in $markers) {
      foreach ($match in $marker.Matches) {
        $name = $match.Groups[1].Value
        if ($captured.Contains($name)) { continue }
        $ackPath = $match.Groups[2].Value
        $focus = & $AdbPath -s $Serial shell dumpsys window
        if ($LASTEXITCODE -ne 0 -or $focus -match 'mCurrentFocus=.*Application Not Responding' -or
            -not ($focus -match 'mFocusedApp=.*community\.planets\.app')) {
          throw "App window is obscured or unavailable: $Serial $name"
        }
        & $AdbPath -s $Serial shell screencap -p "/sdcard/$name.png"
        if ($LASTEXITCODE -ne 0) { throw "Native screencap failed: $Serial $name" }
        $destination = Join-Path $captureDirectory "$name.png"
        & $AdbPath -s $Serial pull "/sdcard/$name.png" $destination | Out-Null
        if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $destination).Length -eq 0) {
          throw "Native capture pull failed: $Serial $name"
        }
        & $AdbPath -s $Serial shell run-as community.planets.app touch $ackPath
        if ($LASTEXITCODE -ne 0) { throw "Capture acknowledgement failed: $name $ackPath" }
        $captured.Add($name) | Out-Null
        Write-Output "Captured $name"
      }
    }
  }
  Start-Sleep -Milliseconds 200
}
if ($captured.Count -ne 14) { throw "Expected 14 $Phase captures; received $($captured.Count). See $LogPath." }
