# Guia 03 — OpenSSH, WinSCP, Apache2 + PHP e Controlador Web (`squidadmin`)

Este guia implementa o controlador Web real do anexo [`squidadmin/`](../squidadmin/) no Ubuntu: configura **OpenSSH** para o **WinSCP**, instala **Apache2 + PHP**, publica o painel em **`/var/www`**, ajusta permissões de arquivo e **`sudoers`** (para que o botão **Alterar** realmente recarregue o Squid) e valida o login em `http://<IP_DO_LINUX>/index.php`.

> **Navegação:** [Índice (README)](../README.md) | **Anterior:** [Guia 02 — Instalação e Configuração do Squid](02-instalacao-configuracao-squid.md) | **Próximo:** [Guia 04 — Testes no Navegador e Troubleshooting](04-testes-cliente-e-troubleshooting.md)

---

## Pré-requisitos

- [Guia 01](01-virtualbox-e-ubuntu.md) e [Guia 02](02-instalacao-configuracao-squid.md) concluídos (`ping` OK, Squid ativo e os 8 arquivos em `/etc/squid/acls/` já criados);
- Pasta **`squidadmin/`** (ou o arquivo `squid.zip` original) presente no Windows;
- **WinSCP** instalado no Windows *(ou PowerShell com `scp`)*.

> **Atalho automatizado:** se você já concluiu o Guia 01 com OpenSSH ativo e deseja aplicar todos os passos dos **Guias 02 e 03** automaticamente de uma vez, envie `squidadmin/` e [`setup-servidor.sh`](../setup-servidor.sh) para o Ubuntu (em comandos `scp` separados ou via WinSCP) e execute `ssh -t <seu_usuario>@<IP_DO_LINUX> "sudo bash ~/setup-servidor.sh 192.168.56.0/24"`. Para executar e entender manualmente etapa por etapa, siga abaixo.

---

## 1. Instale OpenSSH Server e `unzip` no Ubuntu

O **WinSCP** conecta via SFTP (porta `22`). No terminal do Ubuntu:

```bash
sudo apt update
sudo apt install openssh-server unzip -y
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

- Se o **UFW** estiver ativo (`sudo ufw status`), libere a porta `22` para sua rede local:
  ```bash
  sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
  ```

---

## 2. Instale o Apache2 e o Suporte a PHP

Em sala foi indicado `apt-get install apache2`. Como todo o controlador Web (`index.php`, `valida_login.php`, `bloquear_sites.php`, etc.) é escrito em **PHP**, instale também `php` e `libapache2-mod-php`:

```bash
sudo apt-get update
sudo apt-get install apache2 php libapache2-mod-php -y
sudo systemctl enable --now apache2
sudo systemctl status apache2
```

- Se o **UFW** estiver ativo, libere a porta `80` (HTTP) para a rede local:
  ```bash
  sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp
  ```

### Teste rápido do Apache antes de enviar o painel

No navegador do **Windows**, abra `http://<IP_DO_LINUX>`. Deve aparecer a página padrão **"Apache2 Default Page"**.

---

## 3. Envie o `squidadmin` (ou `squid.zip`) do Windows para o Ubuntu via WinSCP

### Opção A — Usando o WinSCP (recomendado em sala)

1. Abra o **WinSCP** no Windows e preencha:
   - **Protocolo de arquivo:** `SFTP`
   - **Nome do host:** `<IP_DO_LINUX>`
   - **Número da porta:** `22`
   - **Usuário / Senha:** os do seu Ubuntu
2. Clique em **Login** e aceite a chave do host na primeira conexão (**Sim**).
3. **Lado esquerdo (Windows):** vá até a pasta do trabalho (`Trabalho de Redes`), onde está a pasta `squidadmin` (ou o `squid.zip`).
4. **Lado direito (Ubuntu):** mantenha em `/home/<seu_usuario>`.
5. Arraste a pasta **`squidadmin`** (ou o arquivo **`squid.zip`**) da esquerda para a direita.

> **Por que enviar primeiro para `/home/<seu_usuario>`?**  
> A pasta `/var/www` pertence ao usuário `root`, então arrastar direto para `/var/www` pelo WinSCP dá *Permission denied*. Enviando para sua pasta pessoal, movemos/extraímos com `sudo` no passo seguinte sem erro.

### Opção B — Alternativa pelo PowerShell do Windows (`scp`)

Na pasta do projeto no Windows:

```powershell
# Se você estiver enviando a pasta squidadmin já extraída:
scp -r .\squidadmin <seu_usuario>@<IP_DO_LINUX>:~/

# OU, se estiver enviando o arquivo squid.zip:
scp .\squid.zip <seu_usuario>@<IP_DO_LINUX>:~/
```

---

## 4. Publique o `squidadmin` em `/var/www` e Configure o `DocumentRoot`

### 4.1. Coloque os arquivos em `/var/www/squidadmin`

No terminal do Ubuntu, execute o comando correspondente ao que você enviou:

```bash
# Se enviou a pasta squidadmin:
sudo rm -rf /var/www/squidadmin
sudo cp -r ~/squidadmin /var/www/squidadmin

# OU, se enviou squid.zip:
sudo unzip -o ~/squid.zip -d /var/www
```

Confirme exatamente onde ficou o arquivo `index.php`:

```bash
find /var/www -maxdepth 3 -name "index.php"
```

- Se aparecer **`/var/www/squidadmin/index.php`**, siga exatamente o Passo 4.2 abaixo.
- Se aparecer **`/var/www/index.php`**, use `DocumentRoot /var/www` no Passo 4.2.

### 4.2. Aponte o Apache para servir `http://<IP_DO_LINUX>/index.php`

Para que o endereço pedido em sala (`http://<IP_DO_LINUX>/index.php`) abra diretamente o painel sem precisar digitar subpasta na URL:

1. Faça backup do VirtualHost padrão:
   ```bash
   sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
   ```
2. Edite o arquivo:
   ```bash
   sudo nano /etc/apache2/sites-available/000-default.conf
   ```
3. Altere a linha `DocumentRoot /var/www/html` para o diretório onde está o `index.php`:
   ```apache
   DocumentRoot /var/www/squidadmin
   ```
   *(Se o `index.php` ficou direto em `/var/www/index.php`, coloque `DocumentRoot /var/www`.)*
4. Salve (`Ctrl + O`, `Enter`, `Ctrl + X`), valide e reinicie o Apache:
   ```bash
   sudo apache2ctl configtest
   sudo systemctl restart apache2
   ```
   *(Saída esperada do `configtest`: `Syntax OK`.)*

---

## 5. Ajuste as Permissões dos Arquivos (Web + ACLs do Squid)

O Apache roda como usuário **`www-data`** e o Squid roda como usuário **`proxy`**. Execute os comandos abaixo para garantir que:
- O Apache leia e exiba o site `/var/www/squidadmin`;
- O PHP consiga abrir e gravar os 8 arquivos em `/etc/squid/acls/`;
- O Squid consiga ler os 8 arquivos de ACL.

```bash
# Permissões do painel Web
sudo chown -R www-data:www-data /var/www/squidadmin
sudo chmod -R 755 /var/www/squidadmin

# Permissões da pasta e dos 8 arquivos de ACL do Squid
sudo chown -R www-data:proxy /etc/squid/acls
sudo chmod 755 /etc/squid/acls /etc/squid/acls/bloqueados /etc/squid/acls/liberados
sudo chmod 644 /etc/squid/acls/bloqueados/* /etc/squid/acls/liberados/*
```

> **Atenção:** garanta que todos os 8 arquivos existem (criados no Passo 5 do Guia 02). Se algum deles faltar, abrir a tela correspondente no navegador causa loop infinito no `while(!feof($arquivo))` do PHP! Confira com:
> ```bash
> ls -la /etc/squid/acls/bloqueados /etc/squid/acls/liberados
> ```

---

## 6. Configure o `sudoers` para o Painel Recarregar o Squid (OBRIGATÓRIO)

Ao analisar o código-fonte de `squidadmin/bloquear_*.php` e `liberar_*.php`, cada página executa exatamente estes dois comandos quando você clica em **Alterar**:

```php
exec("sudo /usr/bin/sort $local -o $local");
exec("sudo /usr/sbin/squid -k reconfigure");
```

Por padrão, o usuário `www-data` **não tem permissão** de rodar `sudo`, então clicar em **Alterar** salvaria o arquivo sem recarregar o Squid. Vamos criar um arquivo `sudoers` seguro e restrito apenas aos comandos exatos usados pelo `squidadmin` (os 8 arquivos + `squid -k reconfigure`):

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
```

- **Saída esperada do `visudo -cf`:** `/etc/sudoers.d/squidadmin: parsed OK`.
- **Teste a permissão como `www-data`:**
  ```bash
  sudo -u www-data sudo /usr/sbin/squid -k reconfigure
  ```
  *(Não deve pedir senha e não deve retornar erro.)*

---

## 7. Acesse e Faça Login no Controlador Web (Windows)

1. Abra o navegador no **Windows** e acesse:
   ```text
   http://<IP_DO_LINUX>/index.php
   ```
2. Na tela **Painel de Controle**, entre com as credenciais padrão de laboratório definidas em [`squidadmin/valida_login.php`](../squidadmin/valida_login.php):
   - **Login:** `user`
   - **Senha:** `@@1234!!aabbcc`
   > *Nota de segurança:* estas são apenas as credenciais didáticas originais do código-base em ambiente isolado. Fora de laboratório, altere a autenticação para senhas com hash (`password_hash`/`password_verify`) e utilize HTTPS.
3. Clique em **Entrar**.
4. **Resultado esperado:** redireciona para `inicio.php` exibindo a mensagem de boas-vindas e o menu superior ativo:
   - **Bloquear por:** `sites` | `palavras` | `ips` | `logins`
   - **Liberar por:** `sites` | `palavras` | `ips` | `logins`

### Observações úteis sobre a interface do `squidadmin`

- **Links `Impressoras` e `Sarg` no topo:** apontam para `http://localhost/jasmine` e `http://localhost/sarg` (são links legados do template original e não fazem parte dos serviços instalados neste trabalho).
- **Rodapé personalizável:** o arquivo `/var/www/squidadmin/rodape.php` já está configurado com um texto limpo de identificação do projeto (sem dados pessoais); se quiser, você pode editá-lo na sua VM para colocar o nome da turma ou do grupo durante a apresentação.
- **Formato ao digitar no painel:** digite **um item por linha**, sem linhas em branco sobrando e sem espaços extras (ex.: `example.com` em *Bloquear sites*, `futebol` em *Bloquear palavras*, `192.168.56.1` em *Liberar/Bloquear IPs*).

---

## 8. Snapshot e Checklist de Saída do Guia 03

Salve um snapshot no VirtualBox: **`03 - Squid + Apache + squidadmin OK`**.

### Checklist
- [ ] `openssh-server`, `unzip`, `apache2`, `php` e `libapache2-mod-php` instalados e serviços `ssh` e `apache2` ativos
- [ ] Pasta `squidadmin` transferida via WinSCP (ou `scp`) para `/var/www/squidadmin`
- [ ] `DocumentRoot` do Apache ajustado e validado com `sudo apache2ctl configtest` (`Syntax OK`)
- [ ] Permissões aplicadas em `/var/www/squidadmin` (`www-data:www-data`) e `/etc/squid/acls` (`www-data:proxy`)
- [ ] `/etc/sudoers.d/squidadmin` validado com `sudo visudo -cf` e testado com `sudo -u www-data sudo /usr/sbin/squid -k reconfigure`
- [ ] Página `http://<IP_DO_LINUX>/index.php` abrindo no Windows e login `user` / `@@1234!!aabbcc` funcionando
- [ ] Telas *Bloquear por sites/palavras/ips* e *Liberar por sites/palavras/ips* abrindo e salvando sem erros
