# Guia 04 — Configuração do Proxy no Navegador, Testes no `squidadmin` e Troubleshooting

Com o **Squid** e o controlador Web **`squidadmin`** operacionais no Ubuntu, este guia mostra como configurar o proxy no navegador do **Windows**, executar um roteiro completo de demonstração prática (bloqueando e liberando sites, palavras e IPs pelo painel Web) e resolver os erros mais comuns.

> **Navegação:** [Índice (README)](../README.md) | **Anterior:** [Guia 03 — Apache, WinSCP e Controlador Web](03-apache-winscp-controlador-web.md) | **Próximo:** [Guia 05 — Comandos Rápidos](05-comandos-rapidos.md)

---

## 1. Configure o Navegador no Cliente Windows

Informe os parâmetros do seu servidor Ubuntu:

| Campo | Valor |
| :--- | :--- |
| **Tipo** | Proxy HTTP |
| **Servidor** | `<IP_DO_LINUX>` (IP da VM Ubuntu) |
| **Porta** | `3128` |
| **Proxy HTTPS** | Mesmo servidor (`<IP_DO_LINUX>`) e porta (`3128`) |
| **Exceções ("Sem proxy para")** | `localhost, 127.0.0.1, <IP_DO_LINUX>` |

> **Por que adicionar `<IP_DO_LINUX>` nas exceções?**  
> Assim o navegador acessa o painel `http://<IP_DO_LINUX>/index.php` diretamente no Apache (porta `80`) sem passar pelo Squid. Isso garante que você nunca perca acesso ao controlador Web — mesmo se bloquear o próprio IP do Windows durante um teste!

### Opção A — Ativação em 1 Clique via Script (Recomendado — Chrome, Edge e Firefox, Guia Normal e Anônima)

Para não precisar abrir menus do navegador ou do Windows toda vez que ligar/desligar a VM, use os scripts prontos na pasta [`scripts/`](../scripts/):

1. **Ligar o proxy (HTTP + HTTPS + exceção automática para o painel):**
   - Dê dois cliques em **`scripts/ativar-proxy.bat`** *(ou rode `.\scripts\ativar-proxy.ps1` no PowerShell)*.
   - O script detecta automaticamente o IP ativo da VM no DHCP Host-Only do VirtualBox, testa se a porta `3128` está respondendo (para nunca te deixar sem internet se a VM estiver desligada) e ativa o Proxy do Sistema Windows instantaneamente.
   - *(Para testar usando o arquivo PAC servido pelo Apache2, execute `.\scripts\ativar-proxy.ps1 -UsePac`.)*
2. **Desligar o proxy ao terminar os testes:**
   - Dê dois cliques em **`scripts/desativar-proxy.bat`** *(ou rode `.\scripts\desativar-proxy.ps1`)*.

> **Como funciona nos navegadores (inclusive na guia anônima):**
> - **Google Chrome e Microsoft Edge:** usam automaticamente o Proxy do Sistema Windows tanto na **guia normal** quanto na **guia anônima**.
> - **Mozilla Firefox:** em *Configurações → Configurações de rede → Configurar conexão*, deixe marcada a opção **"Usar configurações de proxy do sistema"** — assim o Firefox também segue os scripts de 1 clique em guias normais e privadas.

### Opção B — Configuração Manual no Mozilla Firefox (isolado do restante do Windows)

Caso prefira configurar o proxy manualmente apenas dentro do Firefox:

1. Abra o **Firefox** → menu (`☰`) → **Configurações**.
2. Role até o fim em **Configurações de rede** → clique em **Configurar conexão...**.
3. Marque **Configuração manual de proxy**:
   - **Proxy HTTP:** `<IP_DO_LINUX>` | **Porta:** `3128`
   - **OBRIGATÓRIO marcar:** **`Usar também este proxy para HTTPS`** *(se ficar desmarcado, sites HTTPS como YouTube e a janela privada do Firefox — que força HTTPS automaticamente — passam fora do Squid!)*.
   - **Sem proxy para:** `localhost, 127.0.0.1, <IP_DO_LINUX>`
4. *(Alternativa PAC no Firefox):* marque **Endereço para configuração automática de proxy** e informe `http://<IP_DO_LINUX>/proxy.pac`.
5. Clique em **OK**.

### Opção C — Configuração Manual Global no Windows (Chrome / Edge)

1. Abra **Configurações do Windows** (`Win + I`) → **Rede e Internet** → **Proxy**.
2. Em **Configuração manual de proxy** → **Configurar**:
   - Ative **Usar um servidor proxy**
   - **Endereço IP do proxy:** `<IP_DO_LINUX>`
   - **Porta:** `3128`
   - **Não usar proxy para endereços que comecem com:** `localhost;127.0.0.1;<IP_DO_LINUX>`
3. Clique em **Salvar**.

> **Lembrete:** ao encerrar o trabalho e desligar a VM Ubuntu, execute **`scripts/desativar-proxy.bat`** (ou desative o proxy manual no navegador/Windows) para voltar a navegar normalmente.

> **Por que ainda é necessário apontar o proxy no cliente?**  
> Um **Proxy Transparente** (`intercept`) exige que o servidor Linux seja o roteador/gateway físico da rede entre o cliente e a internet. Como aqui o **Windows é o host físico** que fornece internet à VM via NAT, redirecionar o gateway do Windows para a VM criaria loop de roteamento (além de exigir certificado CA instalado para HTTPS). Por isso, o proxy explícito com scripts de 1 clique ou `proxy.pac` é a solução correta para esta topologia.

> **Nota sobre HTTPS:** o proxy HTTPS usa o método **`CONNECT`**, abrindo um túnel criptografado até o site de destino. O Squid controla e registra o domínio/porta (`443`), mas não descriptografa o tráfego HTTPS automaticamente.

---

## 2. Roteiro de Testes Práticos (Usando o `squidadmin`)

Antes de testar no navegador, deixe o log de acessos aberto no terminal do Ubuntu para visualizar cada requisição em tempo real:

```bash
sudo tail -f /var/log/squid/access.log
```

### Teste 1 — Navegação normal passando pelo Squid

1. No navegador configurado com o proxy, abra:
   - `http://example.com`
   - `https://www.wikipedia.org`
2. Confirme no `access.log` do Ubuntu o aparecimento do **IP do Windows** com status `200` (`TCP_MISS/200` ou `TCP_TUNNEL/200`).

### Teste 2 — Bloqueio de site pelo painel Web (`squidadmin`)

1. Em outra aba, abra `http://<IP_DO_LINUX>/index.php` e faça login (`user` / `@@1234!!aabbcc`).
2. Clique em **Bloquear por: sites**.
3. Digite um site de teste no campo de texto (ex.: `example.com` ou `uol.com.br`) e clique em **Alterar**.
4. No terminal do Ubuntu, confira se o arquivo foi gravado:
   ```bash
   cat /etc/squid/acls/bloqueados/dominios
   ```
5. Recarregue `http://example.com` com **`Ctrl + F5`** (recarregamento forçado sem cache) — ou em aba anônima, desde que o navegador não use VPN/DoH próprio nem desative extensões de proxy no modo anônimo.
6. **Resultado esperado:**
   - **Em sites HTTP** (ex.: `http://example.com`): o navegador exibe a página HTML de bloqueio do Squid (*"A URL solicitada não pode ser recuperada / Acesso Negado"*).
   - **Em sites HTTPS** (ex.: `https://www.youtube.com`): o navegador exibe erro de conexão/túnel (ex.: *"Não há conexão com a Internet"* / `ERR_TUNNEL_CONNECTION_FAILED`), pois o Squid recusa o túnel `CONNECT :443` com `403 Forbidden` e os navegadores modernos não exibem páginas HTML do proxy em requisições HTTPS por segurança.
   - Em ambos os casos, o `access.log` registra **`TCP_DENIED/403`**.

> **Dica para testes repetidos no Google Chrome (túneis abertos e cache local):**  
> Ao bloquear um site que você acabou de visitar (especialmente sites HTTPS como YouTube), o Chrome pode reutilizar um túnel `CONNECT` já aberto ou o cache local:
> 1. **No painel Web (1 clique):** abra **Derrubar conexões (Flush)** (`encerrar_conexoes.php`) e clique em **Reiniciar Squid e derrubar túneis ativos** — isso encerra imediatamente todos os túneis HTTPS ativos no servidor (com `shutdown_lifetime 1 seconds`).
> 2. **Cache local do navegador:** por segurança, páginas web não podem limpar o cache interno do Chrome sozinhas; para sites HTTP cacheados no disco (como `example.com`), pressione **`Ctrl + Shift + R`** ou copie `chrome://net-internals/#sockets` no botão da própria tela de Flush para clicar em **Flush socket pools**.

> **Nota sobre aba anônima:** sugerimos `Ctrl + F5` ou aba anônima apenas para evitar que o cache local do navegador exiba uma versão antiga da página. Em alguns navegadores (ex.: Opera com VPN nativa, Chrome/Edge com extensões de proxy desativadas no modo anônimo, ou HTTPS-Only/DoH diferenciado na janela privada), a aba anônima pode ignorar o proxy — nesse caso, teste na aba normal usando `Ctrl + F5`.

### Teste 3 — Liberação (exceção) pelo painel Web

1. No painel Web, clique em **Liberar por: sites** (ou remova o domínio de *Bloquear por: sites*).
2. Adicione `example.com` em *Liberar por: sites* e clique em **Alterar**.
3. Recarregue `http://example.com` na aba anônima.
4. **Resultado esperado:** o acesso volta a ser permitido (`200`), provando a precedência da regra `dominios_liberados` sobre `dominios_bloqueados`!

### Teste 4 — Bloqueio por palavra

1. No painel Web, clique em **Bloquear por: palavras**, digite uma palavra (ex.: `wikipedia` ou `jogos`) e clique em **Alterar**.
2. Tente acessar uma URL contendo essa palavra em aba anônima → deve retornar **`TCP_DENIED/403`**.
3. Limpe a lista depois do teste e clique em **Alterar**.

### Teste 5 — Bloqueio e liberação por IP

1. Consulte o IP do seu Windows no `access.log` (ex.: `192.168.56.1` ou `192.168.1.10`).
2. Em **Bloquear por: ips**, adicione o IP do Windows e clique em **Alterar** → qualquer navegação pelo proxy passará a dar **`TCP_DENIED/403`** (enquanto o painel Web continua abrindo porque `<IP_DO_LINUX>` está nas exceções de proxy!).
3. Remova o IP do Windows de **Bloquear por: ips** e clique em **Alterar** para restabelecer o acesso.

### Teste 6 — Prova real de dependência do proxy (opcional para apresentação)

```bash
sudo systemctl stop squid    # Navegador deixa de abrir sites externos
sudo systemctl start squid   # Navegação volta imediatamente
```

---

## 3. Como Ler o `/var/log/squid/access.log`

| Código no log | Significado |
| :--- | :--- |
| `TCP_MISS/200` | Requisição liberada; página buscada no servidor de origem. |
| `TCP_HIT/200` ou `TCP_MEM_HIT/200` | Requisição liberada e entregue a partir do cache do Squid. |
| `TCP_TUNNEL/200` | Túnel HTTPS (`CONNECT`) autorizado e estabelecido. |
| `TCP_DENIED/403` | Requisição **bloqueada** por uma regra ACL do Squid. |
| `NONE_NONE/503` | Squid não conseguiu alcançar a internet ou resolver DNS. |

---

## 4. Guia Geral de Troubleshooting

| Sintoma | Causa provável | Diagnóstico | Solução |
| :--- | :--- | :--- | :--- |
| Esqueci o **usuário ou senha** do Ubuntu após instalar | Credenciais da instalação inicial não anotadas | — | Reinicie a VM segurando `Shift` (menu GRUB) → *Advanced options* → *(recovery mode)* → `root`. Rode `ls /home` (ver usuário), `mount -o remount,rw /`, `passwd <usuario>` e `reboot`. |
| Primeiro boot da VM parece travado em `Begin: Loading essential drivers ...` | Modo Hyper-V/NEM do VirtualBox no Windows (ícone da tartaruga verde) | Conferir ícone inferior do VirtualBox | Aguarde 2–4 minutos; o primeiro boot termina sozinho até `login:`. |
| `cannot execute binary file` ao rodar `setup-servidor.sh` | O arquivo foi sobrescrito acidentalmente em um `scp` sem destino, ou corrompido | `file ~/setup-servidor.sh` | Envie sempre em comandos separados (`scp -r squidadmin <user>@<IP>:~/` e `scp setup-servidor.sh <user>@<IP>:~/`) garantindo texto Linux `LF`. |
| Site bloqueia na guia normal, mas **abre na guia anônima** (ex.: Firefox) | Na janela privada o Firefox promove automaticamente para **HTTPS**; se *"Usar também este proxy para HTTPS"* estiver desmarcado (ou se o proxy estiver em extensão desativada na anônima), o HTTPS passa fora do Squid | Verificar `sudo tail -f /var/log/squid/access.log` ao abrir na aba anônima | Marque **"Usar também este proxy para HTTPS"** no Firefox **ou** use `scripts/ativar-proxy.bat` (Proxy do Sistema Windows, que cobre Chrome/Edge/Firefox na guia normal e na anônima). |
| Site HTTPS (ex.: YouTube) continuou abrindo logo após bloquear | URL colada com `https://...` (sem normalização) **ou** aba anterior já mantinha túnel `CONNECT` aberto | `cat /etc/squid/acls/bloqueados/dominios` | Com `squidadmin` atualizado (`normaliza_acl.php`), URLs são normalizadas automaticamente para `youtube.com`. Feche a aba antiga do site e abra uma nova aba para forçar nova conexão `CONNECT`. |
| Página `bloquear_*.php` ou `liberar_*.php` **carrega infinitamente** e trava | Falta criar um dos 8 arquivos em `/etc/squid/acls/` (causa loop infinito no `feof` do PHP 8) | `ls -la /etc/squid/acls/bloqueados /etc/squid/acls/liberados` | Crie os 8 arquivos (Guia 02, Passo 5) e aplique `chown -R www-data:proxy /etc/squid/acls` (Guia 03, Passo 5). |
| Clico em **Alterar**, o texto salva, mas o bloqueio **não faz efeito** até reiniciar na mão | `www-data` sem permissão `sudo` para `squid -k reconfigure` | `sudo -u www-data sudo /usr/sbin/squid -k reconfigure` | Configure `/etc/sudoers.d/squidadmin` conforme Guia 03, Passo 6. |
| Texto salvo pelo painel aparece no arquivo, mas o bloqueio `url_regex` **não casa** com o site | Caractere `\r` (`^M`) de quebra de linha do Windows gravado pelo `<textarea>` | `cat -A /etc/squid/acls/bloqueados/dominios` | Se aparecer `^M` no fim das linhas, limpe com `sudo sed -i 's/\r$//' /etc/squid/acls/*/* && sudo squid -k reconfigure` (ou ajuste o PHP para `str_replace("\r", "", $_POST['arquivo'])`). |
| Todos os sites dão **`403 Access Denied`** | `http_access allow minha_rede` ficou abaixo de `http_access deny all`, ou a sub-rede está errada | `sudo tail -n 10 /var/log/squid/access.log`<br>`sudo grep -n "http_access\|minha_rede" /etc/squid/squid.conf` | Confira o IP do cliente no `access.log`, ajuste a sub-rede em `acl minha_rede`, garanta que fique **antes** de `deny all`, rode `sudo squid -k parse` e reinicie. |
| `sudo squid -k parse` falha com erro de sintaxe | Erro de digitação ou conteúdo antigo do `Squid-conf.odt` colado direto | `sudo squid -k parse` | Restaure `/etc/squid/squid.conf.bak` e adicione apenas o bloco moderno do Guia 02, Passo 6. |
| Navegador baixa `index.php` ou exibe código `<?php` | Falta `php` / `libapache2-mod-php` no Apache | `php -v` | `sudo apt install php libapache2-mod-php -y && sudo systemctl restart apache2`. |
| `404 Not Found` em `http://<IP_DO_LINUX>/index.php` | `DocumentRoot` ainda aponta para `/var/www/html` em vez de `/var/www/squidadmin` | `find /var/www -name "index.php"` | Ajuste `DocumentRoot` em `/etc/apache2/sites-available/000-default.conf` e reinicie o Apache. |
| Erro `500` ou tela branca no `index.php` | Erro interno de PHP ou permissão | `sudo tail -n 50 /var/log/apache2/error.log` | Leia a mensagem de erro exata no log e corrija o arquivo/permissão indicado. |
| Windows ficou sem internet depois de desligar a VM | Proxy manual ainda ativado no Windows ou Firefox | — | Desative a configuração manual de proxy. |

---

## 5. Checklist Final para Entrega / Apresentação

- [ ] VM Ubuntu ligada e `ping <IP_DO_LINUX>` respondendo OK no Windows
- [ ] Squid em `active (running)` na porta `3128` sem erros no `sudo squid -k parse`
- [ ] Apache2 + PHP em `active (running)` na porta `80`
- [ ] Painel `squidadmin` abrindo em `http://<IP_DO_LINUX>/index.php` (login `user` / `@@1234!!aabbcc`)
- [ ] Navegador do Windows configurado no proxy `<IP_DO_LINUX>:3128` (com exceção para `<IP_DO_LINUX>`)
- [ ] Demonstração de bloqueio e liberação pelo painel Web refletida imediatamente em `/var/log/squid/access.log`
