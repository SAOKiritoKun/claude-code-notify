param(
    [string]$Title = "Claude Code Task Done",
    [string]$Sound = "ding.wav"
)

# Sound: filename under C:\Windows\Media\ or full path. Empty string to disable.
# Priority: -Sound param > CC_NOTIFY_SOUND env var > default ding.wav
if ($Sound -eq "ding.wav" -and $env:CC_NOTIFY_SOUND -ne $null) {
    $Sound = $env:CC_NOTIFY_SOUND
}

if (-not [Console]::IsInputRedirected) {
    $Message = "(no input)"
} else {
    try {
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        $raw  = [Console]::In.ReadToEnd()
        $json = $raw | ConvertFrom-Json

        $userMsg = $null

        if ($json.transcript_path -and (Test-Path $json.transcript_path)) {
            $lines = Get-Content $json.transcript_path -Encoding UTF8
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                if (-not $lines[$i].Trim()) { continue }
                try {
                    $entry = $lines[$i] | ConvertFrom-Json
                    if ($entry.type -eq 'user' -and $entry.message) {
                        $content = $entry.message.content
                        if ($content -is [string]) {
                            $userMsg = $content; break
                        } elseif ($content -is [array]) {
                            $text = @($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' '
                            if ($text) { $userMsg = $text; break }
                        }
                    }
                } catch { continue }
            }
        }

        if ($userMsg) {
            $Message = if ($userMsg.Length -gt 200) { $userMsg.Substring(0, 197) + '...' } else { $userMsg }
        } else {
            $Message = "Task completed"
        }
    } catch {
        $Message = "Task completed"
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class TrayNotify {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct NOTIFYICONDATA {
        public int    cbSize;
        public IntPtr hWnd;
        public int    uID;
        public int    uFlags;
        public int    uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
        public int    dwState;
        public int    dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string szInfo;
        public int    uTimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string szInfoTitle;
        public int    dwInfoFlags;
    }

    public const int NIM_ADD    = 0x00000000;
    public const int NIM_MODIFY = 0x00000001;
    public const int NIM_DELETE = 0x00000002;
    public const int NIF_MESSAGE = 0x00000001;
    public const int NIF_ICON    = 0x00000002;
    public const int NIF_TIP     = 0x00000004;
    public const int NIF_INFO    = 0x00000010;
    public const int NIIF_NOSOUND = 0x00000010;

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern bool Shell_NotifyIcon(int dwMessage, ref NOTIFYICONDATA lpData);

    [DllImport("user32.dll")]
    public static extern IntPtr CreateWindowEx(int dwExStyle, string lpClassName, string lpWindowName,
        int dwStyle, int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll")]
    public static extern bool DestroyWindow(IntPtr hWnd);
}
"@

$hWnd = [TrayNotify]::CreateWindowEx(0, "STATIC", "", 0, 0, 0, 0, 0, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$hIcon = [System.Drawing.SystemIcons]::Information.Handle

$nid = New-Object TrayNotify+NOTIFYICONDATA
$nid.cbSize           = [System.Runtime.InteropServices.Marshal]::SizeOf($nid)
$nid.hWnd             = $hWnd
$nid.uID              = 1
$nid.uFlags           = [TrayNotify]::NIF_ICON -bor [TrayNotify]::NIF_TIP -bor [TrayNotify]::NIF_INFO
$nid.hIcon            = $hIcon
$nid.szTip            = $Title
$nid.szInfoTitle      = $Title
$nid.szInfo           = $Message
$nid.uTimeoutOrVersion = 5000
$nid.dwInfoFlags      = [TrayNotify]::NIIF_NOSOUND

[TrayNotify]::Shell_NotifyIcon([TrayNotify]::NIM_ADD, [ref]$nid) | Out-Null

if ($Sound -ne "") {
    if (-not [System.IO.Path]::IsPathRooted($Sound)) {
        $Sound = "C:\Windows\Media\$Sound"
    }
    if (Test-Path $Sound) {
        $player = New-Object System.Media.SoundPlayer $Sound
        $player.Play()
    }
}

Start-Sleep -Seconds 6
[TrayNotify]::Shell_NotifyIcon([TrayNotify]::NIM_DELETE, [ref]$nid) | Out-Null
[TrayNotify]::DestroyWindow($hWnd)
