& "C:\Program Files\WiX Toolset v6.0\bin\x64\heat.exe" dir "C:\Users\dan\WS_Setup_6.UI\WS_Setup_6.UI\bin\Release\net8.0-windows\win-x64\publish" `
  -ag -scom -sreg -srd `
  -dr INSTALLFOLDER `
  -cg AppFilesGroup `
  -gg -g1 `
  -out HarvestFiles.wxs