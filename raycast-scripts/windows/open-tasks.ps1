# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Tasks
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📋
# @raycast.packageName Tasks

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int count);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);
    public static IntPtr FindByTitle(string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, _) => {
            if (!IsWindowVisible(hWnd)) return true;
            int len = GetWindowTextLength(hWnd);
            if (len == 0) return true;
            var sb = new StringBuilder(len + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            if (sb.ToString() == title) { found = hWnd; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@

# Check if task windows already exist
$today = [Win32]::FindByTitle("[Today] Tasks")
$inbox = [Win32]::FindByTitle("[Inbox] Tasks")

if ($today -eq [IntPtr]::Zero -or $inbox -eq [IntPtr]::Zero) {
    # Launch missing windows in parallel
    if ($today -eq [IntPtr]::Zero) {
        Start-Process wt.exe -ArgumentList "--window new --title `"[Today] Tasks`" wsl.exe bash -c `"~/workspace/dloez/raycast-scripts/general/helpers/tdo-today.sh`""
    }
    if ($inbox -eq [IntPtr]::Zero) {
        Start-Process wt.exe -ArgumentList "--window new --title `"[Inbox] Tasks`" wsl.exe bash -c `"~/workspace/dloez/raycast-scripts/general/helpers/tdo-inbox.sh`""
    }

    # Poll until both windows appear (timeout after 5s)
    $timeout = [DateTime]::Now.AddSeconds(5)
    while ([DateTime]::Now -lt $timeout) {
        if ($today -eq [IntPtr]::Zero) { $today = [Win32]::FindByTitle("[Today] Tasks") }
        if ($inbox -eq [IntPtr]::Zero) { $inbox = [Win32]::FindByTitle("[Inbox] Tasks") }
        if ($today -ne [IntPtr]::Zero -and $inbox -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    }
}

# DISPLAY2: starts at X=2560, Y=0, size 2560x1440
# Discord takes top 960px, terminals fill remaining 480px
# Invisible window borders ~7px, compensate with offset
if ($today -ne [IntPtr]::Zero) {
    [Win32]::MoveWindow($today, 2553, 960, 1294, 487, $true)
}
if ($inbox -ne [IntPtr]::Zero) {
    [Win32]::MoveWindow($inbox, 3833, 960, 1294, 487, $true)
}
