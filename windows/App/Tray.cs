// Notification-area icon and its popup menu.
using BlackBreak.Core;

namespace BlackBreak;

internal static unsafe class Tray
{
    public const uint Callback = Native.WM_APP + 1;
    public const int Pause30 = 101, Pause60 = 102, Pause120 = 103, Pause180 = 104, CancelPause = 105,
        CallExemption = 106, Mic = 107, Camera = 108;

    static nint _icon;

    public static void Add(nint hwnd)
    {
        if (_icon == 0) _icon = Native.ExtractIconW(Native.Instance, Environment.ProcessPath ?? "", 0);
        var d = Data(hwnd);
        d.Flags = Native.NIF_MESSAGE | Native.NIF_ICON | Native.NIF_TIP;
        d.CallbackMessage = Callback;
        d.Icon = _icon;
        "BlackBreak".AsSpan().CopyTo(new Span<char>(d.Tip, 128));
        Native.Shell_NotifyIconW(Native.NIM_ADD, &d);
    }

    public static void Remove(nint hwnd)
    {
        var d = Data(hwnd);
        Native.Shell_NotifyIconW(Native.NIM_DELETE, &d);
        if (_icon != 0) Native.DestroyIcon(_icon);
        _icon = 0;
    }

    static NOTIFYICONDATAW Data(nint hwnd) => new() { CbSize = (uint)sizeof(NOTIFYICONDATAW), Hwnd = hwnd, Id = 1 };

    /// Shows the menu at the cursor and returns the chosen command, or 0.
    public static int ShowMenu(nint hwnd, MenuState m)
    {
        var menu = Native.CreatePopupMenu();
        try
        {
            Native.AppendMenuW(menu, Native.MF_STRING | Native.MF_GRAYED, 0, m.Status);
            Native.AppendMenuW(menu, Native.MF_SEPARATOR, 0, null);
            var pause = Native.MF_STRING | (m.PauseEnabled ? 0 : Native.MF_GRAYED);
            for (var i = 0; i < Menu.Pauses.Length; i++)
                Native.AppendMenuW(menu, pause, (nuint)(Pause30 + i), Menu.Pauses[i].label);
            Native.AppendMenuW(menu, Native.MF_STRING | (m.CancelEnabled ? 0 : Native.MF_GRAYED), CancelPause, "Cancel pause");
            Native.AppendMenuW(menu, Native.MF_SEPARATOR, 0, null);
            var grey = m.SettingsEnabled ? 0 : Native.MF_GRAYED;
            Native.AppendMenuW(menu, Native.MF_STRING | grey | (m.CallExemption ? Native.MF_CHECKED : 0), CallExemption, "Wait with the break while I'm in a call");
            Native.AppendMenuW(menu, Native.MF_STRING | grey | (m.ExemptMic ? Native.MF_CHECKED : 0), Mic, "Microphone in use");
            Native.AppendMenuW(menu, Native.MF_STRING | grey | (m.ExemptCamera ? Native.MF_CHECKED : 0), Camera, "Camera in use");
            POINT p;
            Native.GetCursorPos(&p);
            Native.SetForegroundWindow(hwnd); // otherwise the menu does not close on an outside click
            return Native.TrackPopupMenu(menu, Native.TPM_RETURNCMD | Native.TPM_NONOTIFY | Native.TPM_RIGHTBUTTON | Native.TPM_BOTTOMALIGN, p.X, p.Y, 0, hwnd, 0);
        }
        finally { Native.DestroyMenu(menu); }
    }
}
