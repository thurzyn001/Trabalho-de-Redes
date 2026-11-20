<#
.SYNOPSIS
    Desativa o proxy do sistema Windows (manual e PAC), restaurando
    a navegacao direta a internet.
#>
$ErrorActionPreference = "Stop"

function Refresh-WindowsProxy {
    $signature = @'
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
    if (-not ("ProxyUtil.WinInetProxyHelper" -as [type])) {
        Add-Type -MemberDefinition $signature -Name "WinInetProxyHelper" -Namespace "ProxyUtil" | Out-Null
    }
    [ProxyUtil.WinInetProxyHelper]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [ProxyUtil.WinInetProxyHelper]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
Remove-ItemProperty -Path $regPath -Name AutoConfigURL -ErrorAction SilentlyContinue
Refresh-WindowsProxy

Write-Host "[OK] Proxy do Windows DESATIVADO. Navegacao direta restaurada!" -ForegroundColor Green
