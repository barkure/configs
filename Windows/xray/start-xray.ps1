$ErrorActionPreference = 'Stop'

$scriptDirectory = $PSScriptRoot
$configFiles = @(Get-ChildItem -LiteralPath $scriptDirectory -File -Filter '*.json' | Sort-Object Name)

if (-not $configFiles) {
    throw "no xray config files found in: $scriptDirectory"
}

function Select-ConfigPath {
    param(
        [System.IO.FileInfo[]]$Files
    )

    if ($Files.Count -eq 1) {
        return $Files[0].FullName
    }

    Write-Host 'Select xray config:'

    for ($index = 0; $index -lt $Files.Count; $index++) {
        Write-Host ('[{0}] {1}' -f ($index + 1), $Files[$index].Name)
    }

    while ($true) {
        $selection = (Read-Host 'Enter config number').Trim()

        if ($selection -match '^\d+$') {
            $selectedIndex = [int]$selection

            if ($selectedIndex -ge 1 -and $selectedIndex -le $Files.Count) {
                return $Files[$selectedIndex - 1].FullName
            }
        }

        Write-Host 'Invalid selection. Try again.'
    }
}

$configPath = Select-ConfigPath -Files $configFiles
$httpProxy = 'http://127.0.0.1:10809'
$httpsProxy = 'http://127.0.0.1:10809'
$allProxy = 'socks5://127.0.0.1:10808'
$noProxy = 'localhost,127.0.0.1,::1'
$proxyOverride = 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*'
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

$proxyEnv = @{
    HTTP_PROXY = $httpProxy
    HTTPS_PROXY = $httpsProxy
    ALL_PROXY = $allProxy
    NO_PROXY = $noProxy
}

foreach ($entry in $proxyEnv.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'User')
}

Set-ItemProperty -Path $internetSettingsPath -Name ProxyEnable -Value 1
Set-ItemProperty -Path $internetSettingsPath -Name ProxyServer -Value '127.0.0.1:10809'
Set-ItemProperty -Path $internetSettingsPath -Name ProxyOverride -Value $proxyOverride
Update-InternetOptions

$normalizedConfig = [System.IO.Path]::GetFullPath($configPath).ToLowerInvariant()

$existing = Get-CimInstance Win32_Process -Filter "Name = 'xray.exe'" | Where-Object {
    $_.CommandLine -and
    $_.CommandLine.ToLowerInvariant().Contains($normalizedConfig)
}

if ($existing) {
    exit 0
}

Start-Process -FilePath 'xray' -ArgumentList @('run', '--config', $configPath) -WindowStyle Hidden
