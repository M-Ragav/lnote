$WshShell = New-Object -comObject WScript.Shell
$Desktop = [Environment]::GetFolderPath('Desktop')
$Target = (Resolve-Path "$PSScriptRoot\..\build\windows\x64\runner\Release\lnote.exe").Path
$WorkDir = (Resolve-Path "$PSScriptRoot\..\build\windows\x64\runner\Release").Path

# Clean up previous shortcuts if they exist
if (Test-Path "$Desktop\LNote All Widgets.lnk") {
    Remove-Item "$Desktop\LNote All Widgets.lnk" -Force
}
if (Test-Path "$Desktop\LNote Glassy Widget.lnk") {
    Remove-Item "$Desktop\LNote Glassy Widget.lnk" -Force
}
if (Test-Path "$PSScriptRoot\..\Widgets\LNote Widget.lnk") {
    Remove-Item "$PSScriptRoot\..\Widgets\LNote Widget.lnk" -Force
}

# 1. Dashboard Widget (Top-Left of Desktop, 400x200 px)
$s1 = $WshShell.CreateShortcut("$Desktop\LNote Dashboard Widget.lnk")
$s1.TargetPath = $Target
$s1.Arguments = "--widget=dashboard"
$s1.WorkingDirectory = $WorkDir
$s1.Description = "LNote Standalone Dashboard Desktop Widget (400x200)"
$s1.Save()

# 2. Calendar Widget (Middle-Left of Desktop, 400x200 px)
$s2 = $WshShell.CreateShortcut("$Desktop\LNote Calendar Widget.lnk")
$s2.TargetPath = $Target
$s2.Arguments = "--widget=calendar"
$s2.WorkingDirectory = $WorkDir
$s2.Description = "LNote Standalone Calendar Heat Map Desktop Widget (400x200, Middle-Left)"
$s2.Save()

Write-Host "Updated Desktop shortcuts: LNote Dashboard Widget (Top-Left) and LNote Calendar Widget (Middle-Left)!" -ForegroundColor Green
