# Guia 02 — Instalação, ACLs do `squidadmin`, Firewall e Testes do Squid

Este guia detalha a instalação do **Squid** no Ubuntu, a criação da estrutura de arquivos `/etc/squid/acls/` exigida pelo controlador Web **`squidadmin`**, a configuração compatível do `/etc/squid/squid.conf` (explicando como aproveitar o anexo **`Squid-conf.odt`** sem quebrar o Squid moderno), o firewall **UFW**, os testes com `curl` e a leitura dos logs.

> **Navegação:** [Índice (README)](../README.md) | **Anterior:** [Guia 01 — VirtualBox e Ubuntu](01-virtualbox-e-ubuntu.md) | **Próximo:** [Guia 03 — Apache, WinSCP e Controlador Web](03-apache-winscp-controlador-web.md)

---

## Pré-requisitos

Antes de começar, confirme que você concluiu o [Guia 01](01-virtualbox-e-ubuntu.md):
- VM Ubuntu com acesso à internet (`ping -c 4 google.com` OK);
- `ping <IP_DO_LINUX>` respondendo a partir do Windows;
- IP do Ubuntu e faixa de sub-rede anotados (ex.: `192.168.1.0/24` no Bridge ou `192.168.56.0/24` no Host-Only).

---

## 1. Atualize o Ubuntu

No terminal do Ubuntu:

```bash
sudo apt update
sudo apt upgrade -y
```

---

## 2. Instale o Squid e Verifique o Serviço

```bash
sudo apt install squid -y
sudo systemctl status squid
```

- **Resultado esperado:** `Active: active (running)` em verde (pressione `q` para sair).
- Confirme que a porta padrão **3128** está em escuta:
  ```bash
  sudo ss -tlnp | grep 3128
  ```

---

## 3. Faça Backup da Configuração Original

Antes de editar `/etc/squid/squid.conf`, salve uma cópia original:

```bash
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
```

> **Como restaurar o backup se precisar:**
> ```bash
> sudo cp /etc/squid/squid.conf.bak /etc/squid/squid.conf
> sudo systemctl restart squid
> ```

---

## 4. Por Que NÃO Colar o `Squid-conf.odt` Direto no Ubuntu Atual?

O anexo [`Squid-conf.odt`](../Squid-conf.odt) traz um excelente exemplo didático de como o Squid organiza regras de liberação/bloqueio (IPs liberados `admin1..180`, `bloquear_palavras`, `livres` e `fora_palavra`). Porém, ele foi gerado em uma versão antiga do Squid (2.7/3.x) e possui incompatibilidades com o Squid 5/6 do Ubuntu 22.04/24.04:

| Item presente no `Squid-conf.odt` | Problema no Ubuntu atual | Como corrigimos neste guia |
| :--- | :--- | :--- |
| `http_port 3128 transparent` | Opção `transparent` foi removida (substituída por `intercept`, que exige NAT/iptables e quebra proxy manual no navegador) | Manter `http_port 3128` (padrão do Ubuntu para proxy configurado no navegador) |
| `extension_methods`, `acl manager proto cache_object`, `acl all src all` | Diretivas removidas ou embutidas no Squid 5/6 — causam erro no `squid -k parse` | Manter a base moderna do `/etc/squid/squid.conf` do Ubuntu |
| Linhas quebradas pela formatação `.odt` (ex.: `econds ago. Default`, `http_access` dividido em 2 linhas) | Erro de sintaxe imediato | Editar apenas a seção de regras do `squid.conf` original |
| Caminhos antigos (`/etc/squid/bloquear_palavras`, `/etc/squid/livres`, `/etc/squid/fora_palavra`) | Não batem com os arquivos que o painel `squidadmin` edita | Apontar as ACLs diretamente para `/etc/squid/acls/{bloqueados,liberados}/*` |

---

## 5. Crie a Estrutura de Arquivos `/etc/squid/acls/` (Exigida pelo `squidadmin`)

Os scripts PHP do anexo [`squidadmin/`](../squidadmin/) leem e gravam exatamente em **8 arquivos** dentro de `/etc/squid/acls/`. Crie as pastas e todos os 8 arquivos vazios agora:

```bash
sudo mkdir -p /etc/squid/acls/bloqueados /etc/squid/acls/liberados
sudo touch /etc/squid/acls/bloqueados/ips
sudo touch /etc/squid/acls/bloqueados/dominios
sudo touch /etc/squid/acls/bloqueados/palavras
sudo touch /etc/squid/acls/bloqueados/logins
sudo touch /etc/squid/acls/liberados/ips
sudo touch /etc/squid/acls/liberados/dominios
sudo touch /etc/squid/acls/liberados/palavras
sudo touch /etc/squid/acls/liberados/logins
```

Ajuste as permissões para que o **Apache** (`www-data`, que instalaremos no Guia 03) possa gravar e o **Squid** (`proxy`) possa ler. Se o usuário `www-data` ainda não existir antes do Apache ser instalado, você aplicará o `chown` novamente no Guia 03 (aqui deixamos pronto para o Squid já ler sem erro):

```bash
sudo chmod 755 /etc/squid/acls /etc/squid/acls/bloqueados /etc/squid/acls/liberados
sudo chmod 644 /etc/squid/acls/bloqueados/* /etc/squid/acls/liberados/*
ls -la /etc/squid/acls/bloqueados /etc/squid/acls/liberados
```

---

## 6. Configure as ACLs e Regras no `/etc/squid/squid.conf`

### 6.1. Confirme a faixa de IP da sua rede

```bash
ip -4 addr
```

Anote sua sub-rede no formato CIDR:
- Exemplo em **Bridge:** IP `192.168.1.50/24` → sub-rede **`192.168.1.0/24`**
- Exemplo em **Host-Only:** IP `192.168.56.101/24` → sub-rede **`192.168.56.0/24`**

### 6.2. Edite o `/etc/squid/squid.conf`

```bash
sudo nano /etc/squid/squid.conf
```

No Nano:
1. Pressione `Ctrl + W` e pesquise por **`INSERT YOUR OWN RULE`** (ou `http_access deny all`).
2. Logo abaixo do comentário `# INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS` — e **ANTES** de `http_access deny all` — insira o bloco abaixo (substituindo `192.168.1.0/24` pela sua sub-rede real):

```conf
# === Regras do Trabalho (integradas ao Controlador Web squidadmin) ===
# Reduz de 30s para 1s o tempo para encerrar conexoes ativas ao usar o botao "Derrubar conexoes (Flush)"
shutdown_lifetime 1 seconds

acl minha_rede src 192.168.1.0/24

acl ips_liberados src "/etc/squid/acls/liberados/ips"
acl ips_bloqueados src "/etc/squid/acls/bloqueados/ips"
acl dominios_liberados url_regex -i "/etc/squid/acls/liberados/dominios"
acl dominios_bloqueados url_regex -i "/etc/squid/acls/bloqueados/dominios"
acl palavras_liberadas url_regex -i "/etc/squid/acls/liberados/palavras"
acl palavras_bloqueadas url_regex -i "/etc/squid/acls/bloqueados/palavras"

# 1) IPs com acesso total (ignoram bloqueios de sites/palavras)
http_access allow ips_liberados

# 2) IPs totalmente bloqueados
http_access deny ips_bloqueados

# 3) Exceções liberadas (sites e palavras) aplicadas ANTES dos bloqueios
http_access allow minha_rede dominios_liberados
http_access allow minha_rede palavras_liberadas

# 4) Bloqueios por domínio e por palavra
http_access deny dominios_bloqueados
http_access deny palavras_bloqueadas

# 5) Libera o restante da rede local
http_access allow minha_rede
```

> **Por que essa ordem é essencial?**  
> O Squid avalia `http_access` de **cima para baixo** e para na **primeira regra que combinar**:
> - `ips_liberados` vem primeiro, exatamente como descrito em `liberar_ips.php` (*"todos os sites bloqueados também vão estar liberados"*).
> - `ips_bloqueados` bloqueia máquinas específicas antes de qualquer liberação de site.
> - `dominios_liberados` e `palavras_liberadas` vêm antes dos bloqueios para funcionar como exceções (mesma ideia do `livres` e `fora_palavra` do `Squid-conf.odt`).
> - `dominios_bloqueados` e `palavras_bloqueadas` negam os alvos cadastrados no painel.
> - `http_access allow minha_rede` libera o restante da navegação da sua rede.
> - Por fim, permanece a linha original **`http_access deny all`** abaixo do bloco (não remova as regras padrão de segurança `Safe_ports`, `SSL_ports` e `CONNECT`).

> **Sobre `logins` (`bloquear_login.php` e `liberar_login.php`):** os dois arquivos foram criados no passo 5 para que essas abas abram normalmente no painel Web sem erro. Eles só aplicam bloqueio no Squid caso você configure autenticação por usuário/senha (`auth_param basic` + `htpasswd`), que não está ativa no `Squid-conf.odt` base.

3. Salve e feche o Nano: `Ctrl + O` → `Enter` → `Ctrl + X`.

---

## 7. Valide a Sintaxe, Reinicie e Habilite o Serviço

```bash
sudo squid -k parse
```

- **Saída esperada:** nenhum erro `FATAL:` ou `ERROR:`.
  > *Nota:* Enquanto os 8 arquivos em `/etc/squid/acls/` estiverem vazios, o Squid exibirá avisos informativos como `WARNING: empty ACL`. Isso é perfeitamente normal e não impede o funcionamento.

Reinicie e habilite o serviço:

```bash
sudo systemctl restart squid
sudo systemctl enable squid
sudo systemctl status squid
```

- **Resultado esperado:** `Active: active (running)`.

---

## 8. Libere a Porta `3128` no Firewall (UFW), se Estiver Ativo

```bash
sudo ufw status
```

- Se retornar **`Status: inactive`**, pule para o passo 9.
- Se retornar **`Status: active`**, libere a porta `3128` **somente** para a sua rede local (ajuste a sub-rede):

```bash
sudo ufw allow from 192.168.1.0/24 to any port 3128 proto tcp
sudo ufw status numbered
```

> **Segurança:** nunca libere a porta `3128` para `Anywhere` (toda a internet), evitando transformar o servidor em um proxy aberto.

---

## 9. Teste o Squid com `curl`

### 9.1. No próprio Ubuntu

```bash
sudo apt install curl -y
curl -I -x http://127.0.0.1:3128 http://example.com
```

### 9.2. A partir do Windows (PowerShell ou CMD)

Substitua `<IP_DO_LINUX>` pelo IP real do Ubuntu:

```powershell
curl.exe -I -x http://<IP_DO_LINUX>:3128 http://example.com
```

> **Dica (PowerShell):** use sempre **`curl.exe`** no Windows PowerShell, pois `curl` sem `.exe` chama o `Invoke-WebRequest` e dá erro nas flags `-I` e `-x`.

- **Esperado:** `HTTP/1.1 200 OK` (ou redirecionamento `301`/`302`) acompanhado de cabeçalhos `Via:` / `X-Cache:` do Squid.

---

## 10. Consulte os Logs do Squid

### Acompanhar acessos em tempo real

```bash
sudo tail -f /var/log/squid/access.log
```

*(Pressione `Ctrl + C` para sair.)*

### Verificar erros e mensagens do serviço

```bash
sudo tail -f /var/log/squid/cache.log
sudo journalctl -u squid -n 50 --no-pager
```

---

## 11. Snapshot e Checklist de Saída do Guia 02

Salve um snapshot no VirtualBox: **`02 - Squid + ACLs configurados`**.

### Checklist
- [ ] Ubuntu atualizado e `squid` em `Active: active (running)` na porta `3128`
- [ ] Backup `/etc/squid/squid.conf.bak` criado
- [ ] Pastas `/etc/squid/acls/bloqueados` e `/etc/squid/acls/liberados` + os 8 arquivos criados
- [ ] Bloco de ACLs integrado ao `squidadmin` inserido **antes** de `http_access deny all`
- [ ] `sudo squid -k parse` sem erros fatais
- [ ] `curl` local e `curl.exe` a partir do Windows retornando resposta HTTP válida
- [ ] Acesso registrado em `/var/log/squid/access.log`
