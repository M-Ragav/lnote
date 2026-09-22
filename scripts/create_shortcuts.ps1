$WshShell = New-Object -comObject WScript.Shell
$Desktop = [Environment]::GetFolderPath('Desktop')
$Target = (Resolve-Path "$PSScriptRoot\..\build\windows\x64\runner\Release\lnote.exe").Path
$WorkDir = (Resolve-Path "$PSScriptRoot\..\build\windows\x64\runner\Release").Path

# 1. Dashboard Widget
$s1 = $WshShell.CreateShortcut("$Desktop\LNote Dashboard Widget.lnk")
$s1.TargetPath = $Target
$s1.Arguments = "--widget=dashboard"
$s1.WorkingDirectory = $WorkDir
$s1.Description = "LNote Standalone Dashboard Widget"
$s1.Save()

# 2. Calendar Widget
$s2 = $WshShell.CreateShortcut("$Desktop\LNote Calendar Widget.lnk")
$s2.TargetPath = $Target
$s2.Arguments = "--widget=calendar"
$s2.WorkingDirectory = $WorkDir
$s2.Description = "LNote Standalone Calendar Heat Map Widget"
$s2.Save()

# 3. All Widgets
$s3 = $WshShell.CreateShortcut("$Desktop\LNote All Widgets.lnk")
$s3.TargetPath = $Target
$s3.Arguments = "--widget=all"
$s3.WorkingDirectory = $WorkDir
$s3.Description = "LNote All Desktop Widgets"
$s3.Save()

Write-Host "Created 3 shortcuts on your Desktop: LNote Dashboard Widget, LNote Calendar Widget, and LNote All Widgets!" -ForegroundColor Green
