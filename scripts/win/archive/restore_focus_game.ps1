Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class NativeFocus { [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd); }'
$g = Get-Process YuanShen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($g -and $g.MainWindowHandle -ne 0) {
  [void][NativeFocus]::ShowWindowAsync($g.MainWindowHandle,9)
  Start-Sleep -Milliseconds 800
  [void][NativeFocus]::SetForegroundWindow($g.MainWindowHandle)
}
