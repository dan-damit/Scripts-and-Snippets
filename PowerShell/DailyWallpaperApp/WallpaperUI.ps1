Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Config
$archiveDir = "C:\Wallpapers\BingArchive"
$favoritesFile = "$archiveDir\favorites.txt"

if (!(Test-Path $favoritesFile)) { New-Item -ItemType File -Path $favoritesFile | Out-Null }
$favorites = Get-Content $favoritesFile

# Create Form
$form = New-Object Windows.Forms.Form
$form.Text = "Bing Wallpaper Archive"
$form.Size = New-Object Drawing.Size(800, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# ListBox for wallpapers
$listBox = New-Object Windows.Forms.ListBox
$listBox.Size = New-Object Drawing.Size(300, 300)
$listBox.Location = New-Object Drawing.Point(10, 10)
$listBox.Items.AddRange(
    (Get-ChildItem $archiveDir -Filter *.jpg | Sort-Object CreationTime | Select-Object -ExpandProperty Name)
)
$form.Controls.Add($listBox)

# PictureBox for preview
$previewBox = New-Object Windows.Forms.PictureBox
$previewBox.Size = New-Object Drawing.Size(450, 300)
$previewBox.Location = New-Object Drawing.Point(320, 10)
$previewBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$form.Controls.Add($previewBox)

# Update preview when selection changes
$listBox.Add_SelectedIndexChanged({
        $selected = $listBox.SelectedItem
        if ($selected) {
            $path = Join-Path $archiveDir $selected
            $previewBox.Image = [System.Drawing.Image]::FromFile($path)
        }
    })

# Button: Set as Wallpaper
$btnSet = New-Object Windows.Forms.Button
$btnSet.Text = "Set as Wallpaper"
$btnSet.Location = New-Object Drawing.Point(10, 320)
$btnSet.Size = New-Object Drawing.Size(120, 30)
$btnSet.Add_Click({
        $selected = $listBox.SelectedItem
        if ($selected) {
            $path = Join-Path $archiveDir $selected
            Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
            [Wallpaper]::SystemParametersInfo(20, 0, $path, 3)
        }
    })
$form.Controls.Add($btnSet)

# Button: Mark Favorite
$btnFav = New-Object Windows.Forms.Button
$btnFav.Text = "Mark Favorite"
$btnFav.Location = New-Object Drawing.Point(150, 320)
$btnFav.Size = New-Object Drawing.Size(120, 30)
$btnFav.Add_Click({
        $selected = $listBox.SelectedItem
        if ($selected) {
            $favorites = Get-Content $favoritesFile
            if ($favorites -contains $selected) {
                [System.Windows.Forms.MessageBox]::Show("$selected is already marked as favorite.")
            }
            else {
                Add-Content $favoritesFile $selected
                [System.Windows.Forms.MessageBox]::Show("$selected marked as favorite.")
            }
        }
    })
$form.Controls.Add($btnFav)

# Show Form
$form.ShowDialog()