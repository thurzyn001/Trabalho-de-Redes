# Guia 05 — Comandos Rápidos (*Cheat Sheet*)

Folha de consulta rápida com todos os comandos, arquivos, credenciais e portas do trabalho de **Squid + Controlador Web (`squidadmin`)** no Ubuntu (VirtualBox).

> **Navegação:** [Índice (README)](../README.md) | **Anterior:** [Guia 04 — Testes no Navegador e Troubleshooting](04-testes-cliente-e-troubleshooting.md)

---

## 1. Rede e Conectividade

```bash
# [Ubuntu] Ver IP e sub-rede
ip -4 addr

# [Ubuntu] Testar internet e DNS
ping -c 4 8.8.8.8
ping -c 4 google.com

# [Ubuntu] Aplicar rede após editar /etc/netplan/*.yaml
sudo netplan apply
```

```powershell
# [Windows] Ver IPs do host
ipconfig

# [Windows] Testar comunicação com o Ubuntu (tem que responder OK)
ping <IP_DO_LINUX>

# [Windows / VirtualBox] Reservar IP fixo para a VM na rede Host-Only (nunca muda entre Wi-Fis)
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" showvminfo Ubuntu-Squid | Select-String "NIC 2"
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" dhcpserver modify --network="HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter" --mac-address=<MAC_NIC_2> --fixed-address=192.168.56.101
```

---

## 1.1. Provisionamento Automatizado + Proxy 1 Clique no Windows

```powershell
# [Windows] Enviar arquivos separados para o Ubuntu e executar o script completo
scp -r squidadmin <seu_usuario>@<IP_DO_LINUX>:~/
scp setup-servidor.sh <seu_usuario>@<IP_DO_LINUX>:~/
ssh -t <seu_usuario>@<IP_DO_LINUX> "sudo bash ~/setup-servidor.sh 192.168.56.0/24"

# [Windows] Ligar / desligar o proxy do sistema Windows em 1 clique (Chrome, Edge e Firefox)
.\scripts\ativar-proxy.ps1
.\scripts\ativar-proxy.ps1 -UsePac    # Alternativa usando http://<IP_DO_LINUX>/proxy.pac
.\scripts\desativar-proxy.ps1
```

---

## 2. Instalação de Todos os Pacotes (Ubuntu)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install squid apache2 php libapache2-mod-php openssh-server unzip curl -y
sudo systemctl enable --now squid apache2 ssh
```

---

## 3. Estrutura de ACLs Exigida pelo `squidadmin`

```bash
sudo mkdir -p /etc/squid/acls/bloqueados /etc/squid/acls/liberados
sudo touch /etc/squid/acls/bloqueados/{ips,dominios,palavras,logins}
sudo touch /etc/squid/acls/liberados/{ips,dominios,palavras,logins}
sudo chown -R www-data:proxy /etc/squid/acls
sudo chmod 755 /etc/squid/acls /etc/squid/acls/bloqueados /etc/squid/acls/liberados
sudo chmod 644 /etc/squid/acls/bloqueados/* /etc/squid/acls/liberados/*
```

---

## 4. Configuração do Squid (`/etc/squid/squid.conf`)

```bash
# Backup original
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Editar configuração
sudo nano /etc/squid/squid.conf

# Validar sintaxe, reiniciar e verificar status
sudo squid -k parse
sudo systemctl restart squid
sudo systemctl status squid
sudo ss -tlnp | grep 3128
```

### Bloco de regras (inserir ANTES de `http_access deny all`)

```conf
shutdown_lifetime 1 seconds
acl minha_rede src 192.168.1.0/24

acl ips_liberados src "/etc/squid/acls/liberados/ips"
acl ips_bloqueados src "/etc/squid/acls/bloqueados/ips"
acl dominios_liberados url_regex -i "/etc/squid/acls/liberados/dominios"
acl dominios_bloqueados url_regex -i "/etc/squid/acls/bloqueados/dominios"
acl palavras_liberadas url_regex -i "/etc/squid/acls/liberados/palavras"
acl palavras_bloqueadas url_regex -i "/etc/squid/acls/bloqueados/palavras"

http_access allow ips_liberados
http_access deny ips_bloqueados
http_access allow minha_rede dominios_liberados
http_access allow minha_rede palavras_liberadas
http_access deny dominios_bloqueados
http_access deny palavras_bloqueadas
http_access allow minha_rede
```

*(Ajuste `192.168.1.0/24` para sua faixa real, ex.: `192.168.56.0/24` no modo Host-Only.)*

---

## 5. Publicação do `squidadmin`, Apache2 e `sudoers`

```powershell
# [Windows] Alternativa ao WinSCP via terminal
scp -r .\squidadmin <seu_usuario>@<IP_DO_LINUX>:~/
```

```bash
# [Ubuntu] Copiar para /var/www/squidadmin e ajustar permissões
sudo rm -rf /var/www/squidadmin
sudo cp -r ~/squidadmin /var/www/squidadmin
sudo chown -R www-data:www-data /var/www/squidadmin
sudo chmod -R 755 /var/www/squidadmin

# [Ubuntu] Ajustar DocumentRoot para /var/www/squidadmin
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
sudo nano /etc/apache2/sites-available/000-default.conf
sudo apache2ctl configtest
sudo systemctl restart apache2
```

### Regra `sudoers` para o painel conseguir executar `sort` e `squid -k reconfigure`

```bash
sudo tee /etc/sudoers.d/squidadmin > /dev/null << 'EOF'
www-data ALL=(root) NOPASSWD: /usr/sbin/squid -k reconfigure
www-data ALL=(root) NOPASSWD: /usr/bin/systemctl restart squid
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/bloqueados/ips -o /etc/squid/acls/bloqueados/ips
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/bloqueados/logins -o /etc/squid/acls/bloqueados/logins
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/bloqueados/palavras -o /etc/squid/acls/bloqueados/palavras
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/bloqueados/dominios -o /etc/squid/acls/bloqueados/dominios
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/liberados/ips -o /etc/squid/acls/liberados/ips
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/liberados/logins -o /etc/squid/acls/liberados/logins
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/liberados/palavras -o /etc/squid/acls/liberados/palavras
www-data ALL=(root) NOPASSWD: /usr/bin/sort /etc/squid/acls/liberados/dominios -o /etc/squid/acls/liberados/dominios
EOF

sudo chmod 440 /etc/sudoers.d/squidadmin
sudo visudo -cf /etc/sudoers.d/squidadmin
sudo -u www-data sudo /usr/sbin/squid -k reconfigure
```

---

## 6. Firewall UFW (somente se `sudo ufw status` mostrar `active`)

```bash
sudo ufw status
sudo ufw allow from 192.168.1.0/24 to any port 3128 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw status numbered
```

---

## 7. Testes, Credenciais e Logs

```bash
# [Ubuntu] Testar Squid localmente
curl -I -x http://127.0.0.1:3128 http://example.com
```

```powershell
# [Windows PowerShell] Testar Squid remotamente (usar curl.exe!)
curl.exe -I -x http://<IP_DO_LINUX>:3128 http://example.com
```

- **Controlador Web:** `http://<IP_DO_LINUX>/index.php`
- **Login do painel (`valida_login.php`):** `user`
- **Senha do painel (`valida_login.php`):** `@@1234!!aabbcc`
- **Proxy no navegador:** `<IP_DO_LINUX>` | Porta `3128` (exceção: `localhost, 127.0.0.1, <IP_DO_LINUX>`)

```bash
# Logs em tempo real
sudo tail -f /var/log/squid/access.log
sudo tail -f /var/log/squid/cache.log
sudo journalctl -u squid -n 50 --no-pager
sudo tail -n 50 /var/log/apache2/error.log

# Remover eventuais quebras \r (CRLF) se o painel salvar linhas com ^M
sudo sed -i 's/\r$//' /etc/squid/acls/bloqueados/* /etc/squid/acls/liberados/*
sudo squid -k reconfigure
```

---

## 8. Mapa de Caminhos e Portas

| Recurso | Caminho / Porta |
| :--- | :--- |
| Configuração do Squid (e backup) | `/etc/squid/squid.conf` e `/etc/squid/squid.conf.bak` |
| Listas do `squidadmin` (8 arquivos) | `/etc/squid/acls/{bloqueados,liberados}/{ips,dominios,palavras,logins}` |
| Regra `sudoers` do painel Web | `/etc/sudoers.d/squidadmin` |
| Painel Web (`squidadmin`) | `/var/www/squidadmin/index.php` |
| VirtualHost padrão do Apache2 | `/etc/apache2/sites-available/000-default.conf` |
| Logs do Squid | `/var/log/squid/access.log` e `/var/log/squid/cache.log` |
| Log de erros do Apache2 / PHP | `/var/log/apache2/error.log` |
| Portas | Squid `3128/tcp` · Apache `80/tcp` · SSH/WinSCP `22/tcp` |
