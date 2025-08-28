// Runs a PowerShell command asynchronously, capturing output and errors
private static Task<int> RunPwshAsync(
    string command,
    Action<string> onOutput,
    Action<string> onError,
    bool useShellExecute = false,
    string? verb = null)
{
    // 10.1) Locate the PS7 runtime folder in Program Files
    var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
    var pwshPath = Path.Combine(programFiles, "PowerShell", "7", "pwsh.exe");

    if (!File.Exists(pwshPath))
        throw new FileNotFoundException("PowerShell 7 not found at expected location.", pwshPath);

    // 10.2) Build invocation arguments
    var args = $"-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"{command}\"";

    // 10.3) Delegate to your existing process-runner
    return RunProcessAsync(
        pwshPath,
        args,
        onOutput,
        onError ?? (_ => { }),
        useShellExecute: useShellExecute,
        verb: verb
    );
}