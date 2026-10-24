// The warning: a small click-through pill at the top centre of the primary monitor.
using System.Runtime.InteropServices;

namespace BlackBreak;

internal sealed unsafe class Notice : IDisposable
{
    const string ClassName = "BlackBreak.Notice";
    static Notice? _cur;
    static bool _registered;

    string _text = "";
    nint _hwnd, _font;

    public void Show(string text)
    {
        _cur = this;
        _text = text;
        if (!_registered)
        {
            Native.RegisterClass(ClassName, (nint)(delegate* unmanaged<nint, uint, nint, nint, nint>)&WndProc, Native.CreateSolidBrush(Native.Rgb(0x2B, 0x2B, 0x2B)));
            _registered = true;
        }
        var scale = Native.GetDpiForSystem() / 96.0;
        if (_font == 0)
            _font = Native.CreateFontW(-(int)(16 * scale), 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, "Segoe UI");
        if (_hwnd == 0)
        {
            _hwnd = Native.CreateWindowExW(Native.WS_EX_LAYERED | Native.WS_EX_TRANSPARENT | Native.WS_EX_TOPMOST |
                Native.WS_EX_NOACTIVATE | Native.WS_EX_TOOLWINDOW, ClassName, null, Native.WS_POPUP, 0, 0, 10, 10, 0, 0, Native.Instance, 0);
            Native.SetLayeredWindowAttributes(_hwnd, 0, 235, Native.LWA_ALPHA);
        }
        var dc = Native.GetDC(_hwnd);
        var old = Native.SelectObject(dc, _font);
        SIZE size;
        Native.GetTextExtentPoint32W(dc, text, text.Length, &size);
        Native.SelectObject(dc, old);
        Native.ReleaseDC(_hwnd, dc);
        var padX = (int)(22 * scale);
        var h = size.Cy + (int)(16 * scale);
        var w = size.Cx + 2 * padX;
        var x = (Native.GetSystemMetrics(Native.SM_CXSCREEN) - w) / 2;
        var y = (int)(24 * scale);
        Native.SetWindowRgn(_hwnd, Native.CreateRoundRectRgn(0, 0, w + 1, h + 1, h, h), 0);
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
        if (_font != 0) Native.DeleteObject(_font);
        _hwnd = _font = 0;
    }

    void Paint(nint hwnd)
    {
        PAINTSTRUCT ps;
        var dc = Native.BeginPaint(hwnd, &ps);
        RECT r;
        Native.GetClientRect(hwnd, &r);
        Native.SetBkMode(dc, Native.TRANSPARENT);
        Native.SetTextColor(dc, Native.Rgb(0xE6, 0xE6, 0xE6));
        var old = Native.SelectObject(dc, _font);
        Native.DrawTextW(dc, _text, _text.Length, &r, Native.DT_CENTER | Native.DT_SINGLELINE | Native.DT_NOPREFIX | Native.DT_VCENTER);
        Native.SelectObject(dc, old);
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
