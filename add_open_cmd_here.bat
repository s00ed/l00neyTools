@echo off
:: Enhanced script to add both CMD and PowerShell to folder context menu
echo Adding "Open CMD Here" and "Open PowerShell Here" to context menu...

:: Add "Open CMD Here" to folder background context menu
REG ADD "HKCR\Directory\Background\shell\OpenCMD" /ve /d "Open CMD Here" /f
REG ADD "HKCR\Directory\Background\shell\OpenCMD\command" /ve /d "cmd.exe /k cd /d \"%%V\"" /f
REG ADD "HKCR\Directory\Background\shell\OpenCMD" /v "Icon" /d "cmd.exe" /f

:: Add "Open PowerShell Here" to folder background context menu
REG ADD "HKCR\Directory\Background\shell\OpenPS" /ve /d "Open PowerShell Here" /f
REG ADD "HKCR\Directory\Background\shell\OpenPS\command" /ve /d "powershell.exe -NoExit -Command \"Set-Location '%%V'\"" /f
REG ADD "HKCR\Directory\Background\shell\OpenPS" /v "Icon" /d "powershell.exe" /f

:: Add "Open CMD Here" when right-clicking directly on a folder
REG ADD "HKCR\Directory\shell\OpenCMD" /ve /d "Open CMD Here" /f
REG ADD "HKCR\Directory\shell\OpenCMD\command" /ve /d "cmd.exe /k cd /d \"%%1\"" /f
REG ADD "HKCR\Directory\shell\OpenCMD" /v "Icon" /d "cmd.exe" /f

:: Add "Open PowerShell Here" when right-clicking directly on a folder
REG ADD "HKCR\Directory\shell\OpenPS" /ve /d "Open PowerShell Here" /f
REG ADD "HKCR\Directory\shell\OpenPS\command" /ve /d "powershell.exe -NoExit -Command \"Set-Location '%%1'\"" /f
REG ADD "HKCR\Directory\shell\OpenPS" /v "Icon" /d "powershell.exe" /f

echo.
echo Context menu entries added successfully!
echo - "Open CMD Here" for both folder backgrounds and folder icons
echo - "Open PowerShell Here" for both folder backgrounds and folder icons
echo.
echo Note: Run as Administrator for best results
pause
