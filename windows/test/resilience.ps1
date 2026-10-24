# Kill and fail-safe checks on a real Windows session (CI). Usage: resilience.ps1 <path to BlackBreak.exe>
param([Parameter(Mandatory)][string]$Exe)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path $Exe).Path
$dir = Join-Path $env:LOCALAPPDATA 'BlackBreak'
New-Item -ItemType Directory -Force $dir | Out-Null

function Now-Ms { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Write-State($startMs) {
    $boot = (Now-Ms) - [Environment]::TickCount64
    $json = '{"breakStartMs": ' + $startMs + ', "bootMs": ' + $boot + '}'
    [IO.File]::WriteAllText((Join-Path $dir 'state.json'), $json)
}
function Input-Desktop {
    $f = Join-Path $env:TEMP "desk-$([guid]::NewGuid()).txt"
    Start-Process $Exe -ArgumentList '--test-input-desktop', $f -Wait
    Get-Content $f
}
function Procs($filter) {
    Get-CimInstance Win32_Process -Filter "Name='BlackBreak.exe'" | Where-Object { $_.CommandLine -like $filter }
}
function Wait-Until($seconds, [scriptblock]$cond) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) { if (& $cond) { return $true }; Start-Sleep -Milliseconds 300 }
    return $false
}
function Fail($m) { Write-Host "FAIL: $m"; Get-Process BlackBreak -ErrorAction SilentlyContinue | Stop-Process -Force; exit 1 }
function Stop-All {
    Procs '*--watchdog*' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Get-Process BlackBreak -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    # the desktop the killed processes held must not stay: put the input back
    Remove-Item (Join-Path $dir 'state.json') -ErrorAction SilentlyContinue
}

# --- Test A: a break in progress, the app is killed, the watchdog brings it back for the rest only
Write-Host 'A: kill the app during a break'
$start = (Now-Ms) - 5000
Write-State $start
Start-Process $Exe | Out-Null
if (-not (Wait-Until 8 { (Input-Desktop) -eq 'BlackBreak' })) { Fail 'A: the break is not shown after start' }
Write-Host "A: break shown, input desktop is BlackBreak"
function App-Procs { Procs '*' | Where-Object { $_.CommandLine -notlike '*--*' } }
$appPid = (App-Procs | Select-Object -First 1).ProcessId
if (-not $appPid) { Fail 'A: no app process found' }
if (-not (Wait-Until 5 { Procs '*--watchdog*' })) { Fail 'A: no watchdog running' }
Stop-Process -Id $appPid -Force
if (-not (Wait-Until 10 { App-Procs | Where-Object { $_.ProcessId -ne $appPid } })) { Fail 'A: the app was not relaunched' }
Write-Host 'A: app relaunched'
# the break must be gone for good by breakStart + 36 s (resume shows only what was left)
$deadline = $start + 36000
$left = $deadline - (Now-Ms)
if ($left -gt 0) { Start-Sleep -Milliseconds $left }
if ((Input-Desktop) -ne 'Default') { Fail 'A: the break is still on 36 s after it started' }
Write-Host 'A: desktop is Default after the break'
Stop-All

# --- Test B: both die and the desktop is held by nobody who will release it: the watchdog gets it back
Write-Host 'B: the watchdog rescues a held desktop'
$hold = Start-Process $Exe -ArgumentList '--test-hold-desktop' -PassThru
if (-not (Wait-Until 8 { (Input-Desktop) -eq 'BlackBreak' })) { Fail 'B: could not switch to the break desktop' }
Write-State ((Now-Ms) - 40000)
$wd = Start-Process $Exe -ArgumentList '--watchdog', $hold.Id -PassThru
if (-not (Wait-Until 8 { (Input-Desktop) -eq 'Default' })) { Fail 'B: the watchdog did not restore the desktop' }
Write-Host 'B: desktop restored by the watchdog'
Stop-Process -Id $wd.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $hold.Id -Force -ErrorAction SilentlyContinue
Stop-All
Write-Host 'resilience: ok'
