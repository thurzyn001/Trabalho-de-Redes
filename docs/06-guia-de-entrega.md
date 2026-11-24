# Guia 06 — O Que Entregar, Como Entregar e Coleta Automática

Este guia explica **quais arquivos do servidor Ubuntu devem ser entregues** ao professor, o que cada arquivo comprova, quais evidências (prints) ajudam na avaliação e como gerar automaticamente um pacote `.zip` pronto para envio usando [`scripts/coletar-entrega.sh`](../scripts/coletar-entrega.sh).

> **Navegação:** [Índice (README)](../README.md) | **Anterior:** [Guia 05 — Comandos Rápidos](05-comandos-rapidos.md)

---

## 1. O Que Entregar (Mapa dos Arquivos no Ubuntu)

Em trabalhos práticos de Squid + Controlador Web, normalmente são solicitados os arquivos reais de configuração do servidor (`/etc/squid`, Apache HTTP), o código publicado em `/var/www` (`index.php` e demais telas PHP) e provas de funcionamento (`/var/log/squid/access.log`):

| Item solicitado | Caminho real no Ubuntu | O que comprova |
| :--- | :--- | :--- |
| **Configuração do Squid** | `/etc/squid/squid.conf` | Porta `3128`, ordem das ACLs integradas ao `squidadmin` e `shutdown_lifetime` |
| **Listas de ACLs** | `/etc/squid/acls/bloqueados/*`<br>`/etc/squid/acls/liberados/*` | Domínios, palavras, IPs e logins gerenciados pelo painel Web |
| **Configuração HTTP (Apache2)** | `/etc/apache2/sites-available/000-default.conf`<br>`/etc/apache2/conf-available/proxy-pac.conf` | `DocumentRoot` apontado para `/var/www/squidadmin` e MIME type do `proxy.pac` |
| **Permissão `sudoers`** | `/etc/sudoers.d/squidadmin` | Permissão restrita para o `www-data` rodar `sort`, `squid -k reconfigure` e `systemctl restart squid` |
| **Controlador Web (`/var` + `index.php`)** | `/var/www/squidadmin/` *(incluindo `index.php`, `bloquear_*.php`, `liberar_*.php`, `normaliza_acl.php`, `encerrar_conexoes.php`, `proxy.pac`, CSS e imagens)* | Aplicação Web efetivamente publicada e servida pelo Apache2 + PHP |
| **Logs de acesso (`/var/log`)** | `/var/log/squid/access.log` | Evidência real das requisições liberadas (`200`) e bloqueadas (`TCP_DENIED/403`) |
| **Resumo técnico (evidência)** | `evidencias/status-servicos.txt` *(gerado pelo script)* | Versões instaladas, saída do `squid -k parse`, status de `squid`/`apache2` e amostra do `access.log` |

> **Atenção de privacidade (repositório público):**  
> **Nunca** faça `git commit` do pacote `entrega-trabalho-squid.zip` nem do `/var/log/squid/access.log` em um repositório público do GitHub, pois eles contêm registros reais da sua rede e da sua navegação durante os testes. O padrão `entrega-*` já está protegido no [`.gitignore`](../.gitignore).

---

## 2. Como Gerar o Pacote `.zip` Automaticamente (Recomendado)

Com a VM Ubuntu ligada e acessível via SSH (ou WinSCP), o script [`scripts/coletar-entrega.sh`](../scripts/coletar-entrega.sh) coleta todos os arquivos acima preservando a estrutura `/etc/...` e `/var/...`, cria um `LEIA-ME.txt` explicativo e gera o arquivo **`entrega-trabalho-squid.zip`**.

### Opção A — Via PowerShell / Prompt de Comando do Windows (3 comandos)

Na pasta raiz do projeto no Windows (substitua `<SEU_USUARIO>` e `<IP_DA_VM>` pelos seus dados reais):

```powershell
# 1) Enviar o script coletor para a VM Ubuntu
scp scripts/coletar-entrega.sh <SEU_USUARIO>@<IP_DA_VM>:~/

# 2) Executar o coletor no Ubuntu (gera ~/entrega-trabalho-squid.zip)
ssh -t <SEU_USUARIO>@<IP_DA_VM> "sudo bash ~/coletar-entrega.sh"

# 3) Baixar o .zip pronto para o Windows
scp <SEU_USUARIO>@<IP_DA_VM>:~/entrega-trabalho-squid.zip .
```

### Opção B — Usando o WinSCP (interface gráfica)

1. Conecte via **WinSCP** (`SFTP`, porta `22`, `<IP_DA_VM>`) e envie `scripts/coletar-entrega.sh` para `/home/<SEU_USUARIO>`.
2. No terminal da VM (ou via `ssh`), execute:
   ```bash
   sudo bash ~/coletar-entrega.sh
   ```
3. Atualize o painel direito do **WinSCP** (`F5`) e arraste **`entrega-trabalho-squid.zip`** da VM para o seu Windows.

---

## 3. Como Coletar Manualmente (Sem Script)

Caso queira montar o pacote à mão dentro do Ubuntu para entender cada passo:

```bash
# Instalar o utilitário zip, se ainda não estiver instalado
sudo apt update && sudo apt install -y zip

# Criar pasta temporária espelhando /etc e /var
mkdir -p ~/entrega/etc/squid ~/entrega/etc/apache2/sites-available ~/entrega/etc/sudoers.d ~/entrega/var/www ~/entrega/var/log/squid

# Copiar configurações, painel Web e log
sudo cp -a /etc/squid/squid.conf /etc/squid/acls ~/entrega/etc/squid/
sudo cp -a /etc/apache2/sites-available/000-default.conf ~/entrega/etc/apache2/sites-available/
sudo cp -a /etc/sudoers.d/squidadmin ~/entrega/etc/sudoers.d/
sudo cp -a /var/www/squidadmin ~/entrega/var/www/
sudo cp -a /var/log/squid/access.log ~/entrega/var/log/squid/

# Compactar e ajustar dono do arquivo
cd ~/entrega && sudo zip -r ~/entrega-trabalho-squid.zip .
sudo chown $USER:$USER ~/entrega-trabalho-squid.zip
rm -rf ~/entrega
```

Depois basta puxar `~/entrega-trabalho-squid.zip` para o Windows com `scp` ou WinSCP.

---

## 4. Como Conferir o `.zip` no Windows Antes de Enviar

No **PowerShell** (na pasta onde baixou o arquivo), liste o conteúdo do `.zip` para confirmar que nada veio vazio ou faltando:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path ".\entrega-trabalho-squid.zip"))
$z.Entries | Sort-Object FullName | ForEach-Object { "{0,-55} {1,8} bytes" -f $_.FullName, $_.Length }
$z.Dispose()
```

**Estrutura esperada dentro do `.zip`:**

```text
entrega-trabalho-squid.zip
├── LEIA-ME.txt
├── evidencias/
│   └── status-servicos.txt
├── etc/
│   ├── apache2/
│   │   ├── conf-available/proxy-pac.conf
│   │   └── sites-available/000-default.conf
│   ├── squid/
│   │   ├── squid.conf
│   │   └── acls/
│   │       ├── bloqueados/{dominios,ips,logins,palavras}
│   │       └── liberados/{dominios,ips,logins,palavras}
│   └── sudoers.d/squidadmin
└── var/
    ├── log/squid/access.log
    └── www/squidadmin/{index.php,bloquear_*.php,liberar_*.php,encerrar_conexoes.php,normaliza_acl.php,proxy.pac,...}
```

---

## 5. Prints e Evidências Extras Recomendados para a Entrega

Se a plataforma da disciplina aceitar um PDF/documento junto com o `.zip` (ou na hora da apresentação presencial), anexe estes **5 prints** objetivos:

1. **Conectividade:** `ping <IP_DA_VM>` respondendo com `0% de perda` no terminal do Windows.
2. **Controlador Web:** navegador aberto em `http://<IP_DA_VM>/index.php` logado na tela de *Bloquear Sites* com domínios cadastrados (ex.: `example.com`, `youtube.com`).
3. **Bloqueio HTTP:** tela oficial de *Acesso Negado* do Squid ao tentar abrir `http://example.com`.
4. **Bloqueio HTTPS + Flush:** erro de túnel/conexão ao tentar abrir `https://www.youtube.com` e tela *Derrubar conexões (Flush)* no painel.
5. **Auditoria de Logs:** terminal exibindo `/var/log/squid/access.log` com registros `TCP_DENIED/403` e `TCP_MISS/200` / `TCP_TUNNEL/200`.

---

## 6. Checklist Antes de Submeter o Trabalho

- [ ] `entrega-trabalho-squid.zip` gerado com `etc/squid/squid.conf`, `etc/squid/acls/`, `etc/apache2/sites-available/000-default.conf`, `var/www/squidadmin/index.php` e `var/log/squid/access.log`
- [ ] Conferido que `access.log` contém registros reais de bloqueio (`TCP_DENIED/403`) e acesso permitido (`200`)
- [ ] Proxy do Windows desativado (`scripts/desativar-proxy.bat`) e VM desligada de forma limpa (ACPI) após a coleta
- [ ] Confirmado que `entrega-trabalho-squid.zip` **não** foi adicionado ao Git (`git status` limpo)
