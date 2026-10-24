// P/Invoke declarations only. Handles are nint, booleans are int, so nothing needs runtime marshalling.
using System.Runtime.InteropServices;

namespace BlackBreak;

[StructLayout(LayoutKind.Sequential)] internal struct POINT { public int X, Y; }
[StructLayout(LayoutKind.Sequential)] internal struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] internal struct SIZE { public int Cx, Cy; }

[StructLayout(LayoutKind.Sequential)]
internal struct MSG { public nint Hwnd; public uint Message; public nint WParam, LParam; public uint Time; public POINT Pt; public uint Private; }

[StructLayout(LayoutKind.Sequential)]
internal struct WNDCLASSEXW
{
    public uint CbSize, Style;
    public nint WndProc;
    public int ClsExtra, WndExtra;
    public nint Instance, Icon, Cursor, Background, MenuName, ClassName, IconSm;
}

[StructLayout(LayoutKind.Sequential)]
internal unsafe struct PAINTSTRUCT
{
    public nint Hdc;
    public int Erase;
    public RECT Paint;
    public int Restore, IncUpdate;
    public fixed byte Reserved[32];
}

[StructLayout(LayoutKind.Sequential)]
internal struct MONITORINFO { public uint CbSize; public RECT Monitor, Work; public uint Flags; }

[StructLayout(LayoutKind.Sequential)]
internal struct LASTINPUTINFO { public uint CbSize, Time; }

[StructLayout(LayoutKind.Sequential)]
internal unsafe struct NOTIFYICONDATAW
{
    public uint CbSize;
    public nint Hwnd;
    public uint Id, Flags, CallbackMessage;
    public nint Icon;
    public fixed char Tip[128];
    public uint State, StateMask;
    public fixed char Info[256];
    public uint Timeout;
    public fixed char InfoTitle[64];
    public uint InfoFlags;
    public Guid Item;
    public nint BalloonIcon;
}

internal static unsafe partial class Native
{
    public const uint WM_DESTROY = 0x2, WM_CLOSE = 0x10, WM_QUIT = 0x12, WM_PAINT = 0xF, WM_ERASEBKGND = 0x14,
        WM_TIMER = 0x113, WM_SYSCOMMAND = 0x112, WM_DISPLAYCHANGE = 0x7E, WM_POWERBROADCAST = 0x218,
        WM_APP = 0x8000, WM_LBUTTONUP = 0x202, WM_RBUTTONUP = 0x205, WM_NCHITTEST = 0x84, WM_SETCURSOR = 0x20;
    public const uint WS_POPUP = 0x80000000, WS_VISIBLE = 0x10000000;
    public const uint WS_EX_TOPMOST = 0x8, WS_EX_TRANSPARENT = 0x20, WS_EX_TOOLWINDOW = 0x80,
        WS_EX_LAYERED = 0x80000, WS_EX_NOACTIVATE = 0x8000000;
    public const int SW_HIDE = 0, SW_SHOWNOACTIVATE = 4, SM_CXSCREEN = 0, SM_CYSCREEN = 1;
    public const uint SWP_NOSIZE = 1, SWP_NOMOVE = 2, SWP_NOACTIVATE = 0x10, SWP_SHOWWINDOW = 0x40;
    public static readonly nint HWND_TOPMOST = -1;
    public const uint GENERIC_ALL = 0x10000000, DESKTOP_SWITCHDESKTOP = 0x100, DESKTOP_READOBJECTS = 1;
    public const int WH_KEYBOARD_LL = 13, UOI_NAME = 2;
    public const uint DT_CENTER = 1, DT_SINGLELINE = 0x20, DT_NOPREFIX = 0x800, DT_VCENTER = 4, DT_NOCLIP = 0x100;
    public const int TRANSPARENT = 1, BLACK_BRUSH = 4;
    public const uint LWA_ALPHA = 2;
    public const uint MF_STRING = 0, MF_GRAYED = 1, MF_CHECKED = 8, MF_SEPARATOR = 0x800;
    public const uint TPM_RETURNCMD = 0x100, TPM_NONOTIFY = 0x80, TPM_RIGHTBUTTON = 2, TPM_BOTTOMALIGN = 0x20;
    public const uint NIM_ADD = 0, NIM_DELETE = 2, NIF_MESSAGE = 1, NIF_ICON = 2, NIF_TIP = 4;

    // user32
    [LibraryImport("user32.dll", EntryPoint = "RegisterClassExW")] public static partial ushort RegisterClassExW(WNDCLASSEXW* wc);
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateWindowExW(uint exStyle, string cls, string? title, uint style, int x, int y, int w, int h, nint parent, nint menu, nint inst, nint param);
    [LibraryImport("user32.dll")] public static partial nint DefWindowProcW(nint hwnd, uint msg, nint w, nint l);
    [LibraryImport("user32.dll")] public static partial int DestroyWindow(nint hwnd);
    [LibraryImport("user32.dll")] public static partial int ShowWindow(nint hwnd, int cmd);
    [LibraryImport("user32.dll")] public static partial nint SetTimer(nint hwnd, nint id, uint ms, nint proc);
    [LibraryImport("user32.dll")] public static partial int KillTimer(nint hwnd, nint id);
    [LibraryImport("user32.dll")] public static partial int GetMessageW(MSG* msg, nint hwnd, uint min, uint max);
    [LibraryImport("user32.dll")] public static partial int TranslateMessage(MSG* msg);
    [LibraryImport("user32.dll")] public static partial nint DispatchMessageW(MSG* msg);
    [LibraryImport("user32.dll")] public static partial void PostQuitMessage(int code);
    [LibraryImport("user32.dll")] public static partial int PostThreadMessageW(uint thread, uint msg, nint w, nint l);
    [LibraryImport("user32.dll")] public static partial int PostMessageW(nint hwnd, uint msg, nint w, nint l);
    [LibraryImport("user32.dll")] public static partial int EnumDisplayMonitors(nint hdc, RECT* clip, nint proc, nint data);
    [LibraryImport("user32.dll")] public static partial int GetMonitorInfoW(nint mon, MONITORINFO* mi);
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial nint CreateDesktopW(string name, nint device, nint devmode, uint flags, uint access, nint sa);
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial nint OpenDesktopW(string name, uint flags, int inherit, uint access);
    [LibraryImport("user32.dll")] public static partial nint OpenInputDesktop(uint flags, int inherit, uint access);
    [LibraryImport("user32.dll")] public static partial int CloseDesktop(nint desk);
    [LibraryImport("user32.dll")] public static partial int SwitchDesktop(nint desk);
    [LibraryImport("user32.dll")] public static partial int SetThreadDesktop(nint desk);
    [LibraryImport("user32.dll")] public static partial nint GetThreadDesktop(uint thread);
    [LibraryImport("user32.dll")] public static partial int GetUserObjectInformationW(nint obj, int index, char* info, uint len, uint* needed);
    [LibraryImport("user32.dll")] public static partial nint SetWindowsHookExW(int id, nint proc, nint inst, uint thread);
    [LibraryImport("user32.dll")] public static partial int UnhookWindowsHookEx(nint hook);
    [LibraryImport("user32.dll")] public static partial nint CallNextHookEx(nint hook, int code, nint w, nint l);
    [LibraryImport("user32.dll")] public static partial nint BeginPaint(nint hwnd, PAINTSTRUCT* ps);
    [LibraryImport("user32.dll")] public static partial int EndPaint(nint hwnd, PAINTSTRUCT* ps);
    [LibraryImport("user32.dll")] public static partial int InvalidateRect(nint hwnd, RECT* r, int erase);
    [LibraryImport("user32.dll")] public static partial int GetClientRect(nint hwnd, RECT* r);
    [LibraryImport("user32.dll")] public static partial int FillRect(nint hdc, RECT* r, nint brush);
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial int DrawTextW(nint hdc, string text, int len, RECT* r, uint format);
    [LibraryImport("user32.dll")] public static partial int SetWindowPos(nint hwnd, nint after, int x, int y, int w, int h, uint flags);
    [LibraryImport("user32.dll")] public static partial int SetLayeredWindowAttributes(nint hwnd, uint key, byte alpha, uint flags);
    [LibraryImport("user32.dll")] public static partial int SetWindowRgn(nint hwnd, nint rgn, int redraw);
    [LibraryImport("user32.dll")] public static partial int GetSystemMetrics(int index);
    [LibraryImport("user32.dll")] public static partial uint GetDpiForSystem();
    [LibraryImport("user32.dll")] public static partial int GetLastInputInfo(LASTINPUTINFO* li);
    [LibraryImport("user32.dll")] public static partial nint LoadCursorW(nint inst, nint name);
    [LibraryImport("user32.dll")] public static partial int ShowCursor(int show);
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial uint RegisterWindowMessageW(string name);
    [LibraryImport("user32.dll")] public static partial nint CreatePopupMenu();
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial int AppendMenuW(nint menu, uint flags, nuint id, string? text);
    [LibraryImport("user32.dll")] public static partial int DestroyMenu(nint menu);
    [LibraryImport("user32.dll")] public static partial int TrackPopupMenu(nint menu, uint flags, int x, int y, int reserved, nint hwnd, nint rect);
    [LibraryImport("user32.dll")] public static partial int GetCursorPos(POINT* p);
    [LibraryImport("user32.dll")] public static partial int SetForegroundWindow(nint hwnd);
    [LibraryImport("user32.dll")] public static partial int DestroyIcon(nint icon);

    // gdi32
    [LibraryImport("gdi32.dll")] public static partial nint GetStockObject(int obj);
    [LibraryImport("gdi32.dll")] public static partial nint CreateSolidBrush(uint color);
    [LibraryImport("gdi32.dll", StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateFontW(int h, int w, int esc, int orient, int weight, uint italic, uint underline, uint strike, uint charset, uint outPrec, uint clipPrec, uint quality, uint pitch, string face);
    [LibraryImport("gdi32.dll")] public static partial nint SelectObject(nint hdc, nint obj);
    [LibraryImport("gdi32.dll")] public static partial int DeleteObject(nint obj);
    [LibraryImport("gdi32.dll")] public static partial uint SetTextColor(nint hdc, uint color);
    [LibraryImport("gdi32.dll")] public static partial int SetBkMode(nint hdc, int mode);
    [LibraryImport("gdi32.dll")] public static partial nint CreateRoundRectRgn(int l, int t, int r, int b, int w, int h);
    [LibraryImport("gdi32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial int GetTextExtentPoint32W(nint hdc, string text, int len, SIZE* size);
    [LibraryImport("user32.dll")] public static partial nint GetDC(nint hwnd);
    [LibraryImport("user32.dll")] public static partial int ReleaseDC(nint hwnd, nint hdc);

    // kernel32, shell32
    [LibraryImport("kernel32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial nint GetModuleHandleW(string? name);
    [LibraryImport("kernel32.dll")] public static partial uint GetCurrentThreadId();
    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)] public static partial nint ExtractIconW(nint inst, string file, uint index);
    [LibraryImport("shell32.dll", EntryPoint = "Shell_NotifyIconW")] public static partial int Shell_NotifyIconW(uint msg, NOTIFYICONDATAW* data);

    public static nint Instance => GetModuleHandleW(null);

    /// Name of the desktop that currently receives input, or null when it cannot be opened (secure desktop).
    public static string? InputDesktopName()
    {
        var d = OpenInputDesktop(0, 0, DESKTOP_READOBJECTS);
        if (d == 0) return null;
        try
        {
            var buf = stackalloc char[128];
            uint needed;
            return GetUserObjectInformationW(d, UOI_NAME, buf, 256, &needed) != 0 ? new string(buf) : null;
        }
        finally { CloseDesktop(d); }
    }

    public static bool SwitchToDefault()
    {
        var d = OpenDesktopW("Default", 0, 0, DESKTOP_SWITCHDESKTOP);
        if (d == 0) return false;
        var ok = SwitchDesktop(d) != 0;
        CloseDesktop(d);
        return ok;
    }

    public static nint RegisterClass(string name, nint proc, nint brush)
    {
        fixed (char* n = name)
        {
            var wc = new WNDCLASSEXW
            {
                CbSize = (uint)sizeof(WNDCLASSEXW), WndProc = proc, Instance = Instance,
                Background = brush, ClassName = (nint)n,
            };
            return RegisterClassExW(&wc);
        }
    }

    public static long UnixNow() => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    public static uint Rgb(int r, int g, int b) => (uint)(r | g << 8 | b << 16);
}
