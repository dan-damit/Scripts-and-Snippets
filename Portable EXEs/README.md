# Portable EXEs

## Overview

This folder contains portable executable files generated from PowerShell
scripts.

- **Description**: List of portable EXEs and their purposes in the table below
- **Usage**: Self-elevation as needed, double click to run (obviously)
- **Requirements**: PowerShell 5.1

## Getting Started

1. Download the desired EXE file
2. Run directly (no installation needed)
3. Follow any command-line arguments or prompts

## Featured Files

|        NAME         |           Description                 |  Version |
| ------------------- | ------------------------------------- | -------- |
|   Domain Join.exe   |    Automates Domain join with GUI     |    v1    |
| ScheduleReboot.exe  |     Schedules a one-time reboot       |   v1.1   |
| Remove Inactive Computers.exe | GUI tool for removing stale computer objects in AD | v1.1 |

## Notes

- These are self-contained executables
- No installation required
- Can be run from any directory

## Support

For issues or questions, refer to the [original PowerShell scripts](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/PowerShell).

## Contents

- Clean Stale DNS Entries.exe | Windows Server DNS - grabs zones and loads the
  contents in the window for analysis.

- Domain Join.exe :: automated domain join tool with GUI.

- InstallCert.exe :: Installs my code signing cert into Trusted Publisher store.

- Launch Custom Shell.exe :: This launches a fun custome PS console.

- Remove Inactive Computers.exe :: This GUI tool removes computer objects from AD
  that haven't checked in for a given amount of days.

- ScheduleReboot.exe :: This little GUI tool leverages Task Scheduler to
  schedule a one-time reboot of the workstation or server.

- SignFile.exe :: My personal GUI tool that has my code signing cert embedded into
  it. It will sign a file using that cert (password entry required at
  execution).
  
- System Repair Toolkit.exe :: This is my GUI for a single spot to leverage
  built-in tools like DISM and SFC with specific switches.
