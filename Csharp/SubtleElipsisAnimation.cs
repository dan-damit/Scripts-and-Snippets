private DispatcherTimer _ellipsisTimer;
private int _dotCount;

private string _waitMessage = "Please be patient";
public string WaitMessage
{
    get => _waitMessage;
    set => SetProperty(ref _waitMessage, value);
}

public Ctor()
{
_ellipsisTimer = new DispatcherTimer
{
    Interval = TimeSpan.FromMilliseconds(500)
};
_ellipsisTimer.Tick += UpdateEllipsis;
}

private void UpdateEllipsis(object? sender, EventArgs e)
{
    _dotCount = (_dotCount + 1) % 4;
    WaitMessage = _waitMessage + new string('.', _dotCount);
    _progressController?.SetMessage(WaitMessage);
}