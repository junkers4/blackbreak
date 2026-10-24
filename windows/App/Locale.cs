// Whether the user's Windows language is Slovak.
using System.Runtime.InteropServices;

namespace BlackBreak;

internal static unsafe partial class Locale
{
    [LibraryImport("kernel32.dll")] private static partial int GetUserDefaultLocaleName(char* name, int len);

    public static readonly bool Slovak = IsSlovak();

    static bool IsSlovak()
    {
        var buf = stackalloc char[85];
        return GetUserDefaultLocaleName(buf, 85) > 0 && new string(buf).StartsWith("sk", StringComparison.OrdinalIgnoreCase);
    }
}
