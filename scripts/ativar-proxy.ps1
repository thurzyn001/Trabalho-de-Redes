<#
.SYNOPSIS
    Ativa o proxy do sistema Windows apontando para a VM Ubuntu (Squid).
    Aplica automaticamente ao Chrome, Edge e Firefox ("Usar proxy do sistema"),
    tanto em guias normais quanto em guias anonimas.

.EXAMPLE
    .\ativar-proxy.ps1
    (Detecta automaticamente o IP ativo da VM no DHCP Host-Only do VirtualBox)

.EXAMPLE
    .\ativar-proxy.ps1 -ServerIP 192.168.56.101 -Port 3128

.EXAMPLE
    .\ativar-proxy.ps1 -UsePac
    (Usa o arquivo http://<IP>/proxy.pac servido pelo Apache2)
#>
param(
    [string]$ServerIP = "",
    [int]$Port = 3128,
    [switch]$UsePac
)

$ErrorActionPreference = "Stop"

function Resolve-VmHostOnlyIP {
    $vboxDir = Join-Path $env:USERPROFILE ".VirtualBox"
    if (-not (Test-Path $vboxDir)) { return "" }

    $leaseFiles = Get-ChildItem -Path $vboxDir -Filter "*Host-Only*Dhcpd.leases" -ErrorAction SilentlyContinue
    foreach ($file in $leaseFiles) {
        try {
            [xml]$xml = Get-Content -Path $file.FullName -Raw
            $acked = $xml.Leases.Lease | Where-Object { $_.state -eq "acked" } | Select-Object -First 1
            if ($acked -and $acked.Address.value) {
                return [string]$acked.Address.value
            }
        } catch {
            # ignora arquivo malformado
        }
    }
    return ""
}

function Test-TcpPort {
    param([string]$TargetHost, [int]$TargetPort, [int]$TimeoutMs = 2000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($TargetHost, $TargetPort, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

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

if ([string]::IsNullOrWhiteSpace($ServerIP)) {
    $ServerIP = Resolve-VmHostOnlyIP
}

if ([string]::IsNullOrWhiteSpace($ServerIP)) {
    $ServerIP = (Read-Host "Digite o IP da VM Ubuntu (ex.: 192.168.56.101)").Trim()
}

if ([string]::IsNullOrWhiteSpace($ServerIP)) {
    Write-Host "[ERRO] Nenhum IP informado. Operacao cancelada." -ForegroundColor Red
    exit 1
}

Write-Host "Verificando se o Squid esta acessivel em ${ServerIP}:${Port}..." -ForegroundColor Cyan
if (-not (Test-TcpPort -TargetHost $ServerIP -TargetPort $Port)) {
    Write-Host "[AVISO] Nao foi possivel conectar em ${ServerIP}:${Port}." -ForegroundColor Yellow
    Write-Host "        Verifique se a VM Ubuntu-Squid esta ligada e o servico squid esta ativo." -ForegroundColor Yellow
    Write-Host "        Proxy NAO foi ativado para evitar ficar sem internet." -ForegroundColor Yellow
    exit 1
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

if ($UsePac) {
    $pacUrl = "http://${ServerIP}/proxy.pac"
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
    Set-ItemProperty -Path $regPath -Name AutoConfigURL -Value $pacUrl
    Refresh-WindowsProxy
    Write-Host ""
    Write-Host "[OK] Proxy automatico (PAC) ATIVADO no Windows!" -ForegroundColor Green
    Write-Host "     Script PAC : $pacUrl"
} else {
    $proxyAddr = "${ServerIP}:${Port}"
    $override = "localhost;127.0.0.1;${ServerIP};<local>"
    Remove-ItemProperty -Path $regPath -Name AutoConfigURL -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name ProxyServer -Value $proxyAddr
    Set-ItemProperty -Path $regPath -Name ProxyOverride -Value $override
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 1
    Refresh-WindowsProxy
    Write-Host ""
    Write-Host "[OK] Proxy do Windows ATIVADO com sucesso!" -ForegroundColor Green
    Write-Host "     Servidor   : $proxyAddr (HTTP e HTTPS)"
    Write-Host "     Excecoes   : $override"
}

Write-Host "     Painel Web : http://${ServerIP}/index.php"
Write-Host "     Chrome/Edge: ja aplicam automaticamente (guia normal e anonima)."
Write-Host "     Firefox    : use 'Usar configuracoes de proxy do sistema'."
Write-Host ""
Write-Host "Lembre-se de executar 'desativar-proxy.ps1' quando desligar a VM." -ForegroundColor Cyan
