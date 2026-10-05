$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
dart format lib test scripts
if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
$backendPython = Join-Path (Get-Location) 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $backendPython)) { throw 'Create backend/.venv and install requirements first; see README.' }
Push-Location backend
try {
  & $backendPython -m pytest tests -q
  if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed.' }
} finally { Pop-Location }
Write-Host 'Analysis and automated tests passed. Build the APK and run the emulator/service checks in README next.'
