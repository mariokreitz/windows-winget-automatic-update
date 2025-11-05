@echo off

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0update-winget.ps1\"' -Verb RunAs -WindowStyle Normal -Wait"

echo.
echo Debug run finished. Press any key to close this console...
pause >nul