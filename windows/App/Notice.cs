// The warning: a small click-through pixel box at the top centre of the primary monitor.
using System.Runtime.InteropServices;

namespace BlackBreak;

internal sealed unsafe class Notice : IDisposable
{
    const string ClassName = "BlackBreak.Notice";
    static Notice? _cur;
    static bool _registered;

    string _text = "";
    nint _hwnd;
    int _px = 2;

    public void Show(string text)
    {
        _cur = this;
        _text = text;
        if (!_registered)
        {
            Native.RegisterClass(ClassName, (nint)(delegate* unmanaged<nint, uint, nint, nint, nint>)&WndProc, Native.CreateSolidBrush(Native.Rgb(0x0D, 0x0C, 0x0B)));
            _registered = true;
        }
        var scale = Native.GetDpiForSystem() / 96.0;
        _px = Math.Max(2, (int)Math.Round(2.2 * scale));
        if (_hwnd == 0)
        {
            _hwnd = Native.CreateWindowExW(Native.WS_EX_LAYERED | Native.WS_EX_TRANSPARENT | Native.WS_EX_TOPMOST |
                Native.WS_EX_NOACTIVATE | Native.WS_EX_TOOLWINDOW, ClassName, null, Native.WS_POPUP, 0, 0, 10, 10, 0, 0, Native.Instance, 0);
            Native.SetLayeredWindowAttributes(_hwnd, 0, 245, Native.LWA_ALPHA);
        }
        var w = PixelArt.TextWidth(text, _px) + _px * 10;
        var h = PixelArt.Rows * _px + _px * 8;
        var x = (Native.GetSystemMetrics(Native.SM_CXSCREEN) - w) / 2;
        var y = (int)(24 * scale);
        Native.SetWindowPos(_hwnd, Native.HWND_TOPMOST, x, y, w, h, Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
        Native.InvalidateRect(_hwnd, null, 1);
    }

    public void Hide()
    {
        if (_hwnd != 0) Native.ShowWindow(_hwnd, Native.SW_HIDE);
    }

    public void Dispose()
    {
        if (_hwnd != 0) Native.DestroyWindow(_hwnd);
        _hwnd = 0;
    }

    void Paint(nint hwnd)
    {
        PAINTSTRUCT ps;
        var dc = Native.BeginPaint(hwnd, &ps);
        RECT r;
        Native.GetClientRect(hwnd, &r);
        PixelArt.Rect(dc, PixelArt.Bg, 0, 0, r.Right, r.Bottom);
        PixelArt.Box(dc, 0, 0, r.Right, r.Bottom, _px, PixelArt.Bg, PixelArt.Red, PixelArt.Red);
        PixelArt.Text(dc, _text, _px * 5, _px * 3, _px, PixelArt.Gold, false);
        Native.EndPaint(hwnd, &ps);
    }

    [UnmanagedCallersOnly]
    static nint WndProc(nint hwnd, uint msg, nint w, nint l)
    {
        if (msg == Native.WM_PAINT && _cur != null)
        {
            _cur.Paint(hwnd);
            return 0;
        }
        return Native.DefWindowProcW(hwnd, msg, w, l);
    }
}
