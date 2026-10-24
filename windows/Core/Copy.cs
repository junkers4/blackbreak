namespace BlackBreak.Core;

/// The words of the break screen, in English or Slovak.
public static class Copy
{
    /// Each line is (plain, emphasised); the emphasised part is set in italic.
    public static (string plain, string accent)[] Lines(bool slovak) => slovak
        ? [("Odlož oči.", ""), ("Pozri von oknom, ", "čo najďalej."), ("Potom sa natiahni.", "")]
        : [("Rest your eyes.", ""), ("Look out of the window, ", "as far as you can."), ("Then stretch.", "")];

    public static string Seconds(bool slovak, long n)
    {
        if (!slovak) return n == 1 ? "1 second" : $"{n} seconds";
        if (n == 1) return "1 sekunda";
        return n is >= 2 and <= 4 ? $"{n} sekundy" : $"{n} sekúnd";
    }
}
