// Shared Build silent uninstall command logic for OEM removal.
// Build the silent uninstall command based on the uninstall string
public string BuildSilentCommand(string uninstallString)
{
    if (string.IsNullOrWhiteSpace(uninstallString))
        return string.Empty;

    var (exePath, args) = SplitCommandLine(uninstallString);

    var exeName = Path.GetFileName(exePath).ToLowerInvariant();
    var sb = new StringBuilder();

    if (exeName == "msiexec.exe" || exeName.EndsWith(".msi"))
    {
        if (!args.Contains("/qn", StringComparison.OrdinalIgnoreCase))
            sb.Append("/qn ");
        if (!args.Contains("/norestart", StringComparison.OrdinalIgnoreCase))
            sb.Append("/norestart ");
    }
    else
    {
        if (!args.Contains("/silent", StringComparison.OrdinalIgnoreCase) &&
            !args.Contains("/verysilent", StringComparison.OrdinalIgnoreCase))
        {
            sb.Append("/VERYSILENT /SUPPRESSMSGBOXES ");
        }

        if (!args.Contains("/S ", StringComparison.Ordinal) &&
            !args.EndsWith("/S", StringComparison.Ordinal))
        {
            sb.Append("/S ");
        }
    }

    if (!string.IsNullOrWhiteSpace(args))
        sb.Append(args);

    return $"\"{exePath}\" {sb.ToString().Trim()}";
}

// Splits a command line into executable path and arguments.
public static (string exePath, string parsedArgs) SplitCommandLine(string uninstallString)
{
    if (string.IsNullOrWhiteSpace(uninstallString))
        return (string.Empty, string.Empty);

    uninstallString = uninstallString.Trim();

    if (uninstallString.StartsWith("\""))
    {
        // Find closing quote
        var closingQuote = uninstallString.IndexOf('"', 1);
        if (closingQuote > 0)
        {
            var exe = uninstallString.Substring(1, closingQuote - 1);
            var parsedArgs = uninstallString.Substring(closingQuote + 1).TrimStart();
            return (exe, parsedArgs);
        }
    }

    // No quotes, fallback to first space
    var firstSpace = uninstallString.IndexOf(' ');
    if (firstSpace < 0)
        return (uninstallString, string.Empty);

    var exePath = uninstallString.Substring(0, firstSpace);
    var args = uninstallString.Substring(firstSpace + 1);
    return (exePath, args);
}