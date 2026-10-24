// The words of the break screen, in English or Slovak by the user's language.
using System.Runtime.InteropServices;

namespace BlackBreak;

internal static unsafe partial class Copy
{
    [LibraryImport("kernel32.dll")] private static partial int GetUserDefaultLocaleName(char* name, int len);

    static readonly bool Slovak = IsSlovak();

    static bool IsSlovak()
    {
        var buf = stackalloc char[85];
        return GetUserDefaultLocaleName(buf, 85) > 0 && new string(buf).StartsWith("sk", StringComparison.OrdinalIgnoreCase);
    }

    /// Each line is (plain, emphasised); the emphasised part is set in italic.
    public static readonly (string plain, string accent)[] Lines = Slovak
        ? [("Odlož oči.", ""), ("Pozri von oknom, ", "čo najďalej."), ("Potom sa natiahni.", "")]
        : [("Rest your eyes.", ""), ("Look out of the window, ", "as far as you can."), ("Then stretch.", "")];

    public static string Seconds(long n)
    {
        if (!Slovak) return n == 1 ? "1 second" : $"{n} seconds";
        if (n == 1) return "1 sekunda";
        return n is >= 2 and <= 4 ? $"{n} sekundy" : $"{n} sekúnd";
    }
}
