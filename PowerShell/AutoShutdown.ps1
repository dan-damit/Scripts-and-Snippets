<#
# AutoShutdown.ps1 - Scheduler-friendly edition (idle-based)
#
# Uses Win32 GetLastInputInfo to detect user inactivity,
# then shuts down after $grace of no input.
#>

# Vars
#------
$logRoot       = "$env:ProgramData\AutoShutdown"
$activityLog   = Join-Path $logRoot "ActivityLog.txt"
$transcriptLog = Join-Path $logRoot "AutoShutdown_$(Get-Date -Format 'yyyyMMdd').log"
$errorDump     = Join-Path $logRoot "ErrorDump_$(Get-Date -Format 'yyyyMMdd').log"
$grace         = New-TimeSpan -Hours 36

if (-not (Test-Path $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
}

Start-Transcript -Path $transcriptLog -Append

try {
    #
    # P/Invoke Win32 API to get milliseconds since last user input
    #
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Win32 {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public UInt32 cbSize;
        public UInt32 dwTime;
    }

    public static class IdleTracker {
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        public static UInt32 GetIdleMilliseconds() {
            LASTINPUTINFO lii = new LASTINPUTINFO();
            lii.cbSize = (UInt32)Marshal.SizeOf(typeof(LASTINPUTINFO));
            if (!GetLastInputInfo(ref lii))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return (UInt32)Environment.TickCount - lii.dwTime;
        }
    }
}
"@ -Language CSharp

    function Log($msg) {
        $time  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $clean = ($msg -replace '[^\u0009\u000A\u000D\u0020-\u007E]', '').Trim()
        "$time - $clean" | Out-File $activityLog -Append -Encoding UTF8
    }

    Log "=== AutoShutdown Idle Scan Started ==="

    # Get how long the user has been idle
    $idleMs  = [Win32.IdleTracker]::GetIdleMilliseconds()
    $idleSec = [math]::Round($idleMs / 1000, 0)
    $idleTs  = New-TimeSpan -Seconds $idleSec

    Log ("User idle for {0:hh\:mm\:ss}" -f $idleTs)

    if ($idleTs -ge $grace) {
        Log ("Idle >= {0:hh\:mm\:ss} — shutting down." -f $grace)
        shutdown.exe /s /f /t 0
    }
    else {
        Log ("Idle below threshold ({0:hh\:mm\:ss}/{1:hh\:mm\:ss}) — no action." `
            -f $idleTs, $grace)
    }

    Log "Scan complete."
    Write-Host "Run complete. See logs in $logRoot"
    exit 0
}
catch {
    $dump = "[$(Get-Date -Format 'o')] $($_.Exception.Message) `n$($_.Exception.StackTrace)"
    $dump | Out-File $errorDump -Append -Encoding UTF8
    exit 1
}
finally {
    Stop-Transcript
}