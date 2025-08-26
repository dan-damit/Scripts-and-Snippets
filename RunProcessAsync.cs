// Runs a process asynchronously, capturing output and errors
private static Task<int> RunProcessAsync(
    string exePath,
    string args,
    Action<string> onOutput,
    Action<string> onError,
    bool useShellExecute = false,
    string? verb = null)
{
    if (!File.Exists(exePath))
        throw new FileNotFoundException("Executable not found", exePath);

    var tcs = new TaskCompletionSource<int>();
    var psi = new ProcessStartInfo(exePath, args)
    {
        UseShellExecute = useShellExecute,
        Verb = verb,
        RedirectStandardOutput = !useShellExecute,
        RedirectStandardError = !useShellExecute,
        CreateNoWindow = true
    };

    var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
    if (!useShellExecute)
    {
        proc.OutputDataReceived += (_, e) => { if (e.Data != null) onOutput(e.Data); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data != null) onError(e.Data); };
    }

    proc.Exited += (_, _) =>
    {
        tcs.TrySetResult(proc.ExitCode);
        proc.Dispose();
    };

    proc.Start();
    if (!useShellExecute)
    {
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
    }

    return tcs.Task;
}