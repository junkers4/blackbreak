namespace BlackBreak.Core;

/// The words of the break screen, in English or Slovak.
public static class Copy
{
    /// Each line is (plain, emphasised); the emphasised part is set in italic.
    public static (string plain, string accent)[] Lines(bool slovak) => slovak
        ? [("Odlož oči.", ""), ("Pozri von oknom, ", "čo najďalej."), ("Potom sa natiahni.", "")]
        : [("Rest your eyes.", ""), ("Look out of the window, ", "as far as you can."), ("Then stretch.", "")];

    /// "N seconds" / "N sekúnd", from the core (bb_seconds).
    public static unsafe string Seconds(bool slovak, long n)
    {
        var buf = stackalloc byte[64];
        var len = CoreNative.bb_seconds(buf, n, slovak ? 1 : 0);
        return System.Text.Encoding.UTF8.GetString(buf, (int)len);
    }
}
