// The break screen: a private Win32 desktop with one black popup per monitor and a swallowing keyboard hook.
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using BlackBreak.Core;

namespace BlackBreak;

internal sealed unsafe class BreakDesktop : IDisposable
{
    const string ClassName = "BlackBreak.Break", DesktopName = "BlackBreak";
    // The window procedure is static, and only one break is ever shown.
    static BreakDesktop? _cur;
    static List<(RECT rect, bool primary)>? _monitors;

    readonly Action<string>? _log;
    readonly List<nint> _wins = new();
    readonly ManualResetEventSlim _started = new();
    Thread? _thread;
    volatile uint _tid;
    long _endsAt, _failsafeAt, _lastSec = -1;
    nint _desk, _ctl, _primary, _hook, _fontLine, _fontItalic, _fontCount, _bg;
    int _primaryHeight;

    readonly bool _preview; // CI screenshots: draw on the current desktop, no switch and no hook

    public BreakDesktop(Action<string>? log = null, bool preview = false)
    {
        _log = log;
        _preview = preview;
    }

    public bool Visible => _thread is { IsAlive: true };

    public void Show(long endsAtMs, long failsafeAtMs)
    {
        if (Visible) return;
        _endsAt = endsAtMs;
        _failsafeAt = failsafeAtMs;
        _started.Reset();
        _thread = new Thread(Run) { IsBackground = true };
        _thread.Start();
        _started.Wait(3000);
    }

    public void Hide()
    {
        var t = _thread;
        if (t is not { IsAlive: true }) return;
        _started.Wait(3000);
        Native.PostThreadMessageW(_tid, Native.WM_QUIT, 0, 0);
        t.Join(3000);
    }

    public void Dispose() => Hide();

    void Run()
    {
        _cur = this;
        _tid = Native.GetCurrentThreadId();
        var orig = Native.GetThreadDesktop(_tid);
        var switched = false;
        try
        {
            if (!_preview)
            {
                _desk = Native.CreateDesktopW(DesktopName, 0, 0, 0, Native.GENERIC_ALL, 0);
                if (_desk == 0 || Native.SetThreadDesktop(_desk) == 0) return;
            }
            Native.RegisterClass(ClassName, (nint)(delegate* unmanaged<nint, uint, nint, nint, nint>)&WndProc,
                _bg = Native.CreateSolidBrush(Native.Rgb(0x0D, 0x0C, 0x0B)));
            _ctl = Native.CreateWindowExW(Native.WS_EX_TOOLWINDOW, ClassName, null, Native.WS_POPUP, 0, 0, 1, 1, 0, 0, Native.Instance, 0);
            BuildWindows();
            switched = !_preview && Native.SwitchDesktop(_desk) != 0;
            if (switched) _log?.Invoke("desktop switched");
            if (!_preview) _hook = Native.SetWindowsHookExW(Native.WH_KEYBOARD_LL, (nint)(delegate* unmanaged<int, nint, nint, nint>)&KeyHook, Native.Instance, 0);
            Native.SetTimer(_ctl, 1, 250, 0);
            Native.SetTimer(_ctl, 2, (uint)Math.Clamp(_failsafeAt - Native.UnixNow(), 1, int.MaxValue), 0); // fail-safe, independent of the end time
            _started.Set();
            MSG m;
            while (Native.GetMessageW(&m, 0, 0, 0) > 0)
            {
                Native.TranslateMessage(&m);
                Native.DispatchMessageW(&m);
            }
        }
        finally
        {
            _started.Set();
            if (_hook != 0) Native.UnhookWindowsHookEx(_hook);
            if (switched && Native.SwitchToDefault()) _log?.Invoke("desktop restored");
            foreach (var w in _wins) Native.DestroyWindow(w);
            _wins.Clear();
            if (_ctl != 0) Native.DestroyWindow(_ctl);
            if (_fontLine != 0) Native.DeleteObject(_fontLine);
            if (_fontItalic != 0) Native.DeleteObject(_fontItalic);
            if (_fontCount != 0) Native.DeleteObject(_fontCount);
            if (_bg != 0) Native.DeleteObject(_bg);
            if (_desk != 0)
            {
                Native.SetThreadDesktop(orig);
                Native.CloseDesktop(_desk);
            }
            _hook = _ctl = _primary = _desk = _fontLine = _fontItalic = _fontCount = _bg = 0;
        }
    }

    void BuildWindows()
    {
        foreach (var w in _wins) Native.DestroyWindow(w);
        _wins.Clear();
        _primary = 0;
        _monitors = new();
        Native.EnumDisplayMonitors(0, null, (nint)(delegate* unmanaged<nint, nint, RECT*, nint, int>)&MonitorEnum, 0);
        var mons = _monitors;
        _monitors = null;
        if (mons.Count == 0) // no monitor list: cover the primary screen
            mons.Add((new RECT { Right = Native.GetSystemMetrics(Native.SM_CXSCREEN), Bottom = Native.GetSystemMetrics(Native.SM_CYSCREEN) }, true));
        foreach (var (r, primary) in mons)
        {
            var w = Native.CreateWindowExW(Native.WS_EX_TOPMOST | Native.WS_EX_TOOLWINDOW, ClassName, null,
                Native.WS_POPUP | Native.WS_VISIBLE, r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top, 0, 0, Native.Instance, 0);
            if (w == 0) continue;
            _wins.Add(w);
            Native.SetWindowPos(w, Native.HWND_TOPMOST, 0, 0, 0, 0, Native.SWP_NOSIZE | Native.SWP_NOMOVE | Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
            if (primary)
            {
                _primary = w;
                _primaryHeight = r.Bottom - r.Top;
            }
        }
        if (_primary == 0 && _wins.Count > 0) _primary = _wins[0];
        if (_fontLine != 0) Native.DeleteObject(_fontLine);
        if (_fontItalic != 0) Native.DeleteObject(_fontItalic);
        if (_fontCount != 0) Native.DeleteObject(_fontCount);
        var px = Math.Max(24, _primaryHeight / 17);
        _fontLine = Native.CreateFontW(-px, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, "Georgia");
        _fontItalic = Native.CreateFontW(-px, 0, 0, 0, 400, 1, 0, 0, 1, 0, 0, 5, 0, "Georgia");
        _fontCount = Native.CreateFontW(-Math.Max(14, px / 2), 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, "Segoe UI");
    }

    void Paint(nint hwnd)
    {
        PAINTSTRUCT ps;
        var dc = Native.BeginPaint(hwnd, &ps);
        RECT r;
        Native.GetClientRect(hwnd, &r);
        Native.FillRect(dc, &r, _bg);
        if (hwnd == _primary)
        {
            Native.SetBkMode(dc, Native.TRANSPARENT);
            var px = Math.Max(24, r.Bottom / 17);
            var lh = px * 12 / 10;
            var left = r.Right / 10;
            var top = r.Bottom * 22 / 100;
            var lines = Copy.Lines(Locale.Slovak);
            for (var i = 0; i < lines.Length; i++)
            {
                var (plain, accent) = lines[i];
                var y = top + i * lh;
                var x = left;
                var old = Native.SelectObject(dc, _fontLine);
                Native.SetTextColor(dc, Native.Rgb(0xEC, 0xE8, 0xE1));
                var line = new RECT { Left = x, Top = y, Right = r.Right, Bottom = y + lh };
                Native.DrawTextW(dc, plain, plain.Length, &line, Native.DT_SINGLELINE | Native.DT_NOPREFIX | Native.DT_NOCLIP);
                if (accent.Length > 0)
                {
                    SIZE size;
                    Native.GetTextExtentPoint32W(dc, plain, plain.Length, &size);
                    Native.SelectObject(dc, _fontItalic);
                    Native.SetTextColor(dc, Native.Rgb(0xC9, 0xB9, 0x9A));
                    line.Left = x + size.Cx;
                    Native.DrawTextW(dc, accent, accent.Length, &line, Native.DT_SINGLELINE | Native.DT_NOPREFIX | Native.DT_NOCLIP);
                }
                Native.SelectObject(dc, old);
            }
            var oldCount = Native.SelectObject(dc, _fontCount);
            Native.SetTextColor(dc, Native.Rgb(0x7B, 0x75, 0x6B));
            var cd = Copy.Seconds(Locale.Slovak, Math.Max(0, (_endsAt - Native.UnixNow() + 999) / 1000));
            var rc = new RECT { Left = left, Top = r.Bottom - r.Bottom * 12 / 100, Right = r.Right, Bottom = r.Bottom };
            Native.DrawTextW(dc, cd, cd.Length, &rc, Native.DT_SINGLELINE | Native.DT_NOPREFIX | Native.DT_NOCLIP);
            Native.SelectObject(dc, oldCount);
        }
        Native.EndPaint(hwnd, &ps);
    }

    void OnTimer(nint id)
    {
        var now = Native.UnixNow();
        if (id == 2 || now >= _endsAt || now >= _failsafeAt)
        {
            Native.PostQuitMessage(0);
            return;
        }
        // Ctrl+Alt+Del then Cancel returns to the default desktop: take the input back.
        if (!_preview && Native.InputDesktopName() is { } name && name != DesktopName)
            Native.SwitchDesktop(_desk);
        var sec = (_endsAt - now + 999) / 1000;
        if (sec != _lastSec)
        {
            _lastSec = sec;
            if (_primary != 0) Native.InvalidateRect(_primary, null, 0);
        }
    }

    [UnmanagedCallersOnly]
    static nint WndProc(nint hwnd, uint msg, nint w, nint l)
    {
        try
        {
            var self = _cur;
            if (self != null)
                switch (msg)
                {
                    case Native.WM_PAINT: self.Paint(hwnd); return 0;
                    case Native.WM_ERASEBKGND: return 1;
                    case Native.WM_TIMER when hwnd == self._ctl: self.OnTimer(w); return 0;
                    case Native.WM_DISPLAYCHANGE when hwnd == self._ctl:
                        self.BuildWindows();
                        return 0;
                    case Native.WM_CLOSE: return 0;
                    case Native.WM_SYSCOMMAND: return 0;
                }
        }
        catch { }
        return Native.DefWindowProcW(hwnd, msg, w, l);
    }

    [UnmanagedCallersOnly]
    static int MonitorEnum(nint mon, nint dc, RECT* rect, nint data)
    {
        var mi = new MONITORINFO { CbSize = (uint)sizeof(MONITORINFO) };
        var primary = Native.GetMonitorInfoW(mon, &mi) != 0 && (mi.Flags & 1) != 0;
        _monitors?.Add((*rect, primary));
        return 1;
    }

    [UnmanagedCallersOnly]
    static nint KeyHook(int code, nint w, nint l) => code >= 0 ? 1 : Native.CallNextHookEx(0, code, w, l);
}
