<#PSScriptInfo

.VERSION 1.0.0

.GUID 3f8c9d2e-1a4b-4e6a-9f8a-2b7d4c6e9f3a

.AUTHOR Dan Damit

.COMPANYNAME Workstation Deployment Toolkit

.COPYRIGHT (c) 2025 Dan Damit. All rights reserved.

.TAGS launcher, WPF, technician, backup, restore, setup, deployment

.LICENSEURI https://opensource.org/licenses/MIT

.PROJECTURI https://github.com/dan-damit

.ICONURI https://github.com/dan-damit/WS_Setup_6/blob/main/Assets/WSSetupIcon.ico

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Initial release of technician-friendly launcher UI for Backup, Restore, and Setup tools.
Includes elevation toggle and error handling for missing EXEs.

#>

Add-Type -AssemblyName PresentationFramework

$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Workstation Deployment Toolkit" Height="250" Width="400"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="#1E1E1E">

    <Window.Resources>
        <Style TargetType="Window">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#D0D0D0"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#D0D0D0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="0,5"/>
            <Setter Property="Padding" Value="10,5"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#D0D0D0"/>
        </Style>
    </Window.Resources>

    <DockPanel>
        <!-- Custom Title Bar -->
        <Grid Background="#2D2D30" Height="30" DockPanel.Dock="Top">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>

            <TextBlock Grid.Column="0"
                       Text="Toolkit Launcher"
                       Foreground="White"
                       FontWeight="Bold"
                       FontSize="14"
                       VerticalAlignment="Center"
                       Margin="10,0" />

            <Button x:Name="btnClose"
                    Grid.Column="1"
                    Content="X"
                    Width="30"
                    Height="30"
                    Background="#2D2D30"
                    Foreground="White"
                    BorderThickness="0"
                    FontWeight="Bold"
                    Cursor="Hand"
                    ToolTip="Close"
                    HorizontalAlignment="Right"
                    VerticalAlignment="Center" />
        </Grid>

        <!-- Main Content -->
        <StackPanel Margin="20">
            <TextBlock FontSize="18" FontWeight="Bold" Text="Workstation Deployment Toolkit" Margin="0,0,0,20" HorizontalAlignment="Center"/>
            <Button Name="btnBackup" Width="250" Content="[B] Backup Workstation" Margin="0,5"/>
            <Button Name="btnRestore" Width="250" Content="[R] Restore Workstation" Margin="0,5"/>
            <Button Name="btnSetup"  Width="250" Content="[S] Setup Workstation" Margin="0,5"/>
        </StackPanel>
    </DockPanel>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$XAML)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Add_MouseLeftButtonDown({ $window.DragMove() })

$btnBackup  = $window.FindName("btnBackup")
$btnRestore = $window.FindName("btnRestore")
$btnSetup   = $window.FindName("btnSetup")

function Launch-Tool($exeName) {
    $exeDir = [System.IO.Path]::GetDirectoryName([System.Reflection.Assembly]::GetExecutingAssembly().Location)
    $exePath = Join-Path $exeDir $exeName

    if (-not (Test-Path $exePath)) {
        [System.Windows.MessageBox]::Show("Tool not found: $exeName")
        return
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $exePath
    $startInfo.UseShellExecute = $true

    try {
        [System.Diagnostics.Process]::Start($startInfo)
    } catch {
        [System.Windows.MessageBox]::Show("Failed to launch $exeName`n$_")
    }
}

$btnBackup.Add_Click({ Launch-Tool "BackupWorkstation.exe" })
$btnRestore.Add_Click({ Launch-Tool "RestoreWorkstation.exe" })
$btnSetup.Add_Click({ Launch-Tool "WS Setup.exe" })

$btnClose = $window.FindName("btnClose")
$btnClose.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null