# windows-winget-automatic-update

Tiny script to automate the winget update and upgrade functionality.

## Quick overview
This repository contains a minimal set of scripts to run Windows Package Manager (winget) upgrades automatically.

Files:
- update-winget.ps1 — main PowerShell script that performs the winget update/upgrade operations.
- update.bat — small wrapper to run the PowerShell script non-interactively.
- update-debug.bat — wrapper that runs the script and keeps the console open for debugging/verbose output.

## Requirements
- Windows 10 / Windows 11
- winget (Windows Package Manager) installed
- Administrative privileges are recommended for system-wide upgrades

## Usage
Run manually:
- Double-click `update.bat`, or
- From a PowerShell prompt (run as Administrator):
  powershell -ExecutionPolicy Bypass -File .\update-winget.ps1

For debugging/verbose output:
- Run `update-debug.bat` (keeps the console open so you can read messages).

Scheduling (minimal):
- Create a Task Scheduler task that runs `update.bat` on the schedule you prefer (daily/weekly).
- Configure the task to "Run with highest privileges" if you want system-level updates.

## Notes
- Keep the scripts in a folder accessible to the scheduled task or users that will run them.
- No license specified in this repository.

## Contact
Repository owner: mariokreitz