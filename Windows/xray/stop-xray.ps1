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
