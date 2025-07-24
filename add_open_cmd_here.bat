@echo off
:: Adds "Open CMD Here" to the background right-click menu of folders

REG ADD "HKCR\Directory\Background\shell\OpenCMD" /ve /d "Open CMD Here" /f
REG ADD "HKCR\Directory\Background\shell\OpenCMD\command" /ve /d "cmd.exe /k cd %%V" /f

echo "Open CMD Here" added to folder background context menu.
pause
