$ErrorActionPreference = 'Stop'

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

function Stop-XrayProcesses {
    $targets = @(Get-CimInstance Win32_Process -Filter "Name = 'xray.exe'")

    $targets | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
    }
}

Stop-XrayProcesses

foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    Remove-ItemProperty -Path $userEnvironmentPath -Name $name -ErrorAction SilentlyContinue
}

Set-ItemProperty -Path $internetSettingsPath -Name ProxyEnable -Value 0
Remove-ItemProperty -Path $internetSettingsPath -Name ProxyServer -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $internetSettingsPath -Name ProxyOverride -ErrorAction SilentlyContinue
Update-InternetOptions
