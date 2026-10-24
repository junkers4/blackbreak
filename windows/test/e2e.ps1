# End-to-end checks on a real Windows session (CI). Usage: e2e.ps1 <path to BlackBreak.exe>
# Each section names the requirements it covers (docs/requirements.md).
param([Parameter(Mandatory)][string]$Exe)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path $Exe).Path
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = Join-Path $env:LOCALAPPDATA 'BlackBreak'
New-Item -ItemType Directory -Force $dir | Out-Null

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Inject {
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    public static void Key(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); keybd_event(vk, 0, 2, UIntPtr.Zero); }
    public static void Down(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); }
    public static void Up(byte vk) { keybd_event(vk, 0, 2, UIntPtr.Zero); }
    public static void Type(string s) { foreach (var c in s.ToUpperInvariant()) Key((byte)c); }
    public static void Click(int x, int y) { SetCursorPos(x, y); mouse_event(2, 0, 0, 0, UIntPtr.Zero); mouse_event(4, 0, 0, 0, UIntPtr.Zero); }
}
'@

function Now-Ms { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Write-State($startMs) {
    $boot = (Now-Ms) - [Environment]::TickCount64
    [IO.File]::WriteAllText((Join-Path $dir 'state.json'), '{"breakStartMs": ' + $startMs + ', "bootMs": ' + $boot + '}')
}
function Write-Settings($call, $mic, $cam) {
    $j = '{"callExemption": ' + $call + ', "exemptMic": ' + $mic + ', "exemptCamera": ' + $cam + ', "lastPauseDay": null}'
    [IO.File]::WriteAllText((Join-Path $dir 'settings.json'), $j)
}
function Input-Desktop {
    $f = Join-Path $env:TEMP "desk-$([guid]::NewGuid()).txt"
    Start-Process $Exe -ArgumentList '--test-input-desktop', $f -Wait
    Get-Content $f
}
function Procs($filter) {
    Get-CimInstance Win32_Process -Filter "Name='BlackBreak.exe'" | Where-Object { $_.CommandLine -like $filter }
}
function App-Procs { Procs '*' | Where-Object { $_.CommandLine -notlike '*--*' } }
function Wait-Until($seconds, [scriptblock]$cond) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) { if (& $cond) { return $true }; Start-Sleep -Milliseconds 300 }
    return $false
}
$script:failed = 0
function Check($ok, $what) {
    if ($ok) { Write-Host "  ok   $what" } else { Write-Host "  FAIL $what"; $script:failed++ }
}
function Stop-All {
    Procs '*--watchdog*' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Get-Process BlackBreak -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    Remove-Item (Join-Path $dir 'state.json') -ErrorAction SilentlyContinue
    if ((Input-Desktop) -eq 'BlackBreak') { & $Exe --test-restore-desktop | Out-Null }
}
function Read-Target($log) { (Get-Content $log -ErrorAction SilentlyContinue) -split '\|' }

# ---------------------------------------------------------------------------
Write-Host 'INPUT: keys and clicks do not reach other windows during a break (REQ-004, REQ-022, REQ-023)'
$log = Join-Path $env:TEMP 'target.txt'
Remove-Item $log -ErrorAction SilentlyContinue
$form = Start-Process pwsh -ArgumentList '-NoProfile', '-File', (Join-Path $here 'target-form.ps1'), $log -PassThru
Check (Wait-Until 20 { Test-Path $log }) 'test window is up'
Start-Sleep -Seconds 1
$t = Read-Target $log
[Inject]::Click([int]$t[2], [int]$t[3]); Start-Sleep -Milliseconds 300
[Inject]::Type('ok'); Start-Sleep -Milliseconds 300
[Inject]::Click([int]$t[4], [int]$t[5])
Start-Sleep -Seconds 1
$t = Read-Target $log
Check ($t[0] -eq 'ok' -and $t[1] -eq '1') "before the break typing and clicking reach the window (got '$($t[0])', clicks $($t[1]))"

$start = (Now-Ms) - 3000
Write-State $start
Start-Process $Exe | Out-Null
Check (Wait-Until 10 { (Input-Desktop) -eq 'BlackBreak' }) 'the break is shown (input is on the break desktop)'
[Inject]::Type('abc')
[Inject]::Key(0x5B)                                   # Win
[Inject]::Down(0x12); [Inject]::Key(0x09); [Inject]::Up(0x12)   # Alt+Tab
[Inject]::Down(0x12); [Inject]::Key(0x73); [Inject]::Up(0x12)   # Alt+F4
[Inject]::Down(0x11); [Inject]::Key(0x1B); [Inject]::Up(0x11)   # Ctrl+Esc
1..3 | ForEach-Object { [Inject]::Click([int]$t[4], [int]$t[5]) }
Start-Sleep -Seconds 1
$t2 = Read-Target $log
Check (-not $form.HasExited) 'Alt+F4 during the break did not close the window underneath'
Check ($t2[0] -eq 'ok') "keys during the break did not reach the window (text '$($t2[0])')"
Check ($t2[1] -eq '1') "clicks during the break did not reach the window (clicks $($t2[1]))"

$runKey = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).BlackBreak
Check ($runKey -eq "`"$Exe`"") "starts at login: Run key is set (REQ-018) ($runKey)"

Check (Wait-Until 40 { (Input-Desktop) -eq 'Default' }) 'the break ends by itself'
Check ((Now-Ms) -lt $start + 36000) 'and within 35 s of its start (REQ-006)'
Start-Sleep -Seconds 1
$t = Read-Target $log
[Inject]::Click([int]$t[2], [int]$t[3]); Start-Sleep -Milliseconds 300
[Inject]::Type('z'); Start-Sleep -Milliseconds 600
$t = Read-Target $log
Check ($t[0] -eq 'okz') "after the break typing works again (text '$($t[0])')"
Stop-Process -Id $form.Id -Force -ErrorAction SilentlyContinue
Stop-All

# ---------------------------------------------------------------------------
Write-Host 'KILL: a killed app comes back, for the rest of the break only (REQ-016, REQ-021)'
$start = (Now-Ms) - 5000
Write-State $start
Start-Process $Exe | Out-Null
Check (Wait-Until 8 { (Input-Desktop) -eq 'BlackBreak' }) 'break shown after start'
$appPid = (App-Procs | Select-Object -First 1).ProcessId
Check (Wait-Until 5 { Procs '*--watchdog*' }) 'the watchdog runs'
Stop-Process -Id $appPid -Force
Check (Wait-Until 10 { App-Procs | Where-Object { $_.ProcessId -ne $appPid } }) 'the app is relaunched'
$wdPid = (Procs '*--watchdog*' | Select-Object -First 1).ProcessId
Stop-Process -Id $wdPid -Force
Check (Wait-Until 10 { Procs '*--watchdog*' | Where-Object { $_.ProcessId -ne $wdPid } }) 'a killed watchdog is restarted by the app'
$left = $start + 36000 - (Now-Ms)
if ($left -gt 0) { Start-Sleep -Milliseconds $left }
Check ((Input-Desktop) -eq 'Default') 'the relaunched break does not run past breakStart + 35 s'
Stop-All

# ---------------------------------------------------------------------------
Write-Host 'RESCUE: nobody left to end the break, the watchdog restores the desktop (REQ-006)'
$hold = Start-Process $Exe -ArgumentList '--test-hold-desktop' -PassThru
Check (Wait-Until 8 { (Input-Desktop) -eq 'BlackBreak' }) 'a stuck break desktop is shown'
Write-State ((Now-Ms) - 40000)
$wd = Start-Process $Exe -ArgumentList '--watchdog', $hold.Id -PassThru
Check (Wait-Until 8 { (Input-Desktop) -eq 'Default' }) 'the watchdog restored the desktop'
Stop-Process -Id $wd.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $hold.Id -Force -ErrorAction SilentlyContinue
Stop-All

# ---------------------------------------------------------------------------
Write-Host 'CALLS: the settings decide whether microphone or camera use holds a break (REQ-011, REQ-026..028)'
$cas = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
function Fake-Use($capability) {
    $k = "$cas\$capability\NonPackaged\C:#Fake#Teams.exe"
    New-Item -Path $k -Force | Out-Null
    New-ItemProperty -Path $k -Name LastUsedTimeStart -PropertyType QWord -Value 133000000000000000 -Force | Out-Null
    New-ItemProperty -Path $k -Name LastUsedTimeStop -PropertyType QWord -Value 0 -Force | Out-Null
}
function Clear-Use { foreach ($c in 'microphone', 'webcam') { Remove-Item "$cas\$c\NonPackaged\C:#Fake#Teams.exe" -Recurse -Force -ErrorAction SilentlyContinue } }
function Smoke-Breaks {
    $f = Join-Path $env:TEMP "smoke-$([guid]::NewGuid()).log"
    $env:BLACKBREAK_DEBUG_FAST = '1'
    Start-Process $Exe -ArgumentList '--smoke', '28', $f -Wait
    Remove-Item Env:BLACKBREAK_DEBUG_FAST
    (Get-Content $f -ErrorAction SilentlyContinue) -contains 'phase break'
}
$cases = @(
    @{ name = 'exemption off, microphone in use: the break comes'; s = 'false', 'true', 'true'; use = 'microphone'; brk = $true },
    @{ name = 'exemption on, microphone on, microphone in use: the break waits'; s = 'true', 'true', 'false'; use = 'microphone'; brk = $false },
    @{ name = 'exemption on, microphone off, microphone in use: the break comes'; s = 'true', 'false', 'true'; use = 'microphone'; brk = $true },
    @{ name = 'exemption on, camera on, camera in use: the break waits'; s = 'true', 'false', 'true'; use = 'webcam'; brk = $false },
    @{ name = 'exemption on, camera off, camera in use: the break comes'; s = 'true', 'true', 'false'; use = 'webcam'; brk = $true },
    @{ name = 'exemption on, nothing in use: the break comes'; s = 'true', 'true', 'true'; use = $null; brk = $true }
)
foreach ($c in $cases) {
    Clear-Use
    Write-Settings $c.s[0] $c.s[1] $c.s[2]
    if ($c.use) { Fake-Use $c.use }
    $got = Smoke-Breaks
    Check ($got -eq $c.brk) $c.name
}
Clear-Use
Remove-Item (Join-Path $dir 'settings.json') -ErrorAction SilentlyContinue
Stop-All

# ---------------------------------------------------------------------------
Write-Host 'SCREEN: warm black with light text (REQ-003, REQ-030)'
$p = Start-Process $Exe -ArgumentList '--test-preview', '10' -PassThru
Start-Sleep -Seconds 3
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
[System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
$bmp.Save((Join-Path (Get-Location) 'break-windows.png'))
$corner = $bmp.GetPixel(3, 3)
Check ([Math]::Abs($corner.R - 0x0D) -le 2 -and [Math]::Abs($corner.G - 0x0C) -le 2 -and [Math]::Abs($corner.B - 0x0B) -le 2) "background is #0D0C0B (got $($corner.R),$($corner.G),$($corner.B))"
$bright = 0
for ($x = 0; $x -lt $b.Width; $x += 2) { for ($y = 0; $y -lt [int]($b.Height * 0.5); $y += 2) { if ($bmp.GetPixel($x, $y).R -gt 200) { $bright++ } } }
Check ($bright -gt 300) "the lines are drawn in the upper half ($bright light pixels)"
$p | Wait-Process -Timeout 20 -ErrorAction SilentlyContinue

if ($script:failed) { Write-Host "e2e: $($script:failed) failed"; exit 1 }
Write-Host 'e2e: all passed'
