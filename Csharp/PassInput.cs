// --- Secure password input for console ---
private string ReadPassword()
{
    var pass = string.Empty;
    ConsoleKey key;
    do
    {
        var keyInfo = Console.ReadKey(intercept: true);
        key = keyInfo.Key;

        if (key == ConsoleKey.Backspace && pass.Length > 0)
        {
            pass = pass.Substring(0, pass.Length - 1);
            Console.Write("\b \b"); // erase last char
        }
        else if (!char.IsControl(keyInfo.KeyChar))
        {
            pass += keyInfo.KeyChar;
            Console.Write("*");
        }
    }
    while (key != ConsoleKey.Enter);

    Console.WriteLine();
    return pass;
}