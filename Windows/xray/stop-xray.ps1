$ErrorActionPreference = 'Stop'

$userHome = [Environment]::GetFolderPath('UserProfile')
$configPath = Join-Path $userHome '.config\xray\config.json'
$userEnvironmentPath = 'HKCU:\Environment'
$internetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class WinInet {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
"@

function Update-InternetOptions {
    [void][WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
}

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "xray config not found: $configPath"
}

$normalizedConfig = [System.IO.Path]::GetFullPath($configPath).ToLowerInvariant()

$targets = Get-CimInstance Win32_Process -Filter "Name = 'xray.exe'" | Where-Object {
    $_.CommandLine -and
    $_.CommandLine.ToLowerInvariant().Contains($normalizedConfig)
}

if (-not $targets) {
    $targets = @()
}

$targets | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}

foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    Remove-ItemProperty -Path $userEnvironmentPath -Name $name -ErrorAction SilentlyContinue
}

Set-ItemProperty -Path $internetSettingsPath -Name ProxyEnable -Value 0
Remove-ItemProperty -Path $internetSettingsPath -Name ProxyServer -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $internetSettingsPath -Name ProxyOverride -ErrorAction SilentlyContinue
Update-InternetOptions
