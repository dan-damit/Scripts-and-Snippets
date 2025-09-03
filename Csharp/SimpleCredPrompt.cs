// --- Simple console-based credential prompt  ---
private (string user, string pass)? PromptForCredentials(string sharePath)
{
    Console.WriteLine($"Enter credentials for {sharePath}:");
    Console.Write("Username: ");
    string? user = Console.ReadLine();
    Console.Write("Password: ");
    string? pass = ReadPassword();

    if (!string.IsNullOrWhiteSpace(user) && !string.IsNullOrWhiteSpace(pass))
        return (user, pass);

    return null;
}

// --- Connect to network share ---
private bool ConnectToShare(string sharePath, string username, string password)
{
    var nr = new NETRESOURCE
    {
        dwType = 1, // RESOURCETYPE_DISK
        lpRemoteName = sharePath
    };

    int result = WNetAddConnection2(ref nr, password, username, 0);
    return result == 0;
}