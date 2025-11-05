@echo off

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0update-winget.ps1\"' -Verb RunAs -Wait"

echo.
echo Run finished. Press any key to close this console...
pause >nul