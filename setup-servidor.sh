#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script de configuracao automatica do Trabalho de Redes
# Instala e integra: Squid + ACLs (/etc/squid/acls) + Apache2/PHP + squidadmin
# Uso: sudo bash setup-servidor.sh [SUBREDE_CIDR] [CAMINHO_SQUIDADMIN]
# Exemplo: sudo bash setup-servidor.sh 192.168.56.0/24 /home/usuario/squidadmin
# ==============================================================================

if [ "${EUID}" -ne 0 ]; then
  echo "[ERRO] Execute este script com sudo: sudo bash $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
SUBREDE="${1:-192.168.56.0/24}"
SQUIDADMIN_SRC="${2:-${REAL_HOME}/squidadmin}"
SQUIDZIP_SRC="${REAL_HOME}/squid.zip"

echo "============================================================"
echo " Configurando Servidor Proxy Squid + Controlador Web"
echo " Sub-rede liberada : ${SUBREDE}"
echo " Origem squidadmin : ${SQUIDADMIN_SRC}"
echo "============================================================"

# 1. Atualizar repositorios e instalar pacotes necessarios
echo ""
echo "[1/8] Atualizando APT e instalando pacotes (squid, apache2, php, unzip, curl)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y squid apache2 php libapache2-mod-php openssh-server unzip curl

systemctl enable --now ssh squid apache2

# 2. Backup do squid.conf original (preserva o original mesmo se re-executar)
echo ""
echo "[2/8] Verificando backup de /etc/squid/squid.conf..."
if [ ! -f /etc/squid/squid.conf.bak ]; then
  cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
  echo "  -> Backup criado em /etc/squid/squid.conf.bak"
else
  echo "  -> Backup original ja existe em /etc/squid/squid.conf.bak (mantido)"
fi

# 3. Criar estrutura /etc/squid/acls/{bloqueados,liberados} exigida pelo squidadmin
echo ""
echo "[3/8] Criando estrutura de ACLs em /etc/squid/acls/..."
mkdir -p /etc/squid/acls/bloqueados /etc/squid/acls/liberados
for pasta in bloqueados liberados; do
  for arq in ips dominios palavras logins; do
    touch "/etc/squid/acls/${pasta}/${arq}"
  done
done

chown -R www-data:proxy /etc/squid/acls
chmod 755 /etc/squid/acls /etc/squid/acls/bloqueados /etc/squid/acls/liberados
chmod 644 /etc/squid/acls/bloqueados/* /etc/squid/acls/liberados/*

# 4. Gerar /etc/squid/squid.conf limpo a partir do backup original + regras do squidadmin
echo ""
echo "[4/8] Configurando ACLs integradas em /etc/squid/squid.conf..."
TMP_BLOCO="$(mktemp)"
trap 'rm -f "${TMP_BLOCO}"' EXIT

cat > "${TMP_BLOCO}" <<EOF
# === BEGIN TRABALHO REDES SQUIDADMIN ===
# Encerra conexoes ativas rapidamente (1s) ao reiniciar o Squid pelo botao de Flush do painel
shutdown_lifetime 1 seconds

acl minha_rede src ${SUBREDE}

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
# 3) Excecoes liberadas antes dos bloqueios (sites e palavras)
http_access allow minha_rede dominios_liberados
http_access allow minha_rede palavras_liberadas
# 4) Bloqueios por dominio e por palavra
http_access deny dominios_bloqueados
http_access deny palavras_bloqueadas
# 5) Libera o restante da rede local
http_access allow minha_rede
# === END TRABALHO REDES SQUIDADMIN ===
EOF

awk -v bfile="${TMP_BLOCO}" '
  !inserido && /^[[:space:]]*http_access[[:space:]]+deny[[:space:]]+all([[:space:]]|$)/ {
    while ((getline linha < bfile) > 0) print linha
    close(bfile)
    print ""
    inserido = 1
  }
  { print }
  END {
    if (!inserido) {
      while ((getline linha < bfile) > 0) print linha
      close(bfile)
      print "http_access deny all"
    }
  }
' /etc/squid/squid.conf.bak > /etc/squid/squid.conf

echo "  -> Validando sintaxe com squid -k parse..."
squid -k parse
systemctl restart squid
systemctl is-active --quiet squid && echo "  -> Squid ativo (running)!"

# 5. Publicar o painel Web squidadmin em /var/www/squidadmin
echo ""
echo "[5/8] Publicando controlador Web em /var/www/squidadmin..."
if [ -d "${SQUIDADMIN_SRC}" ]; then
  rm -rf /var/www/squidadmin
  cp -r "${SQUIDADMIN_SRC}" /var/www/squidadmin
  echo "  -> Pasta copiada de ${SQUIDADMIN_SRC}"
elif [ -f "${SQUIDZIP_SRC}" ]; then
  unzip -o "${SQUIDZIP_SRC}" -d /var/www
  echo "  -> Extraido de ${SQUIDZIP_SRC} para /var/www"
else
  echo "[AVISO] Nao encontrei '${SQUIDADMIN_SRC}' nem '${SQUIDZIP_SRC}'."
  echo "        Envie a pasta squidadmin via WinSCP/scp para ${REAL_HOME}/ e rode este script novamente."
fi

DOC_ROOT="/var/www/squidadmin"
if [ -f /var/www/squidadmin/index.php ]; then
  DOC_ROOT="/var/www/squidadmin"
elif [ -f /var/www/index.php ]; then
  DOC_ROOT="/var/www"
fi

if [ -d "${DOC_ROOT}" ]; then
  chown -R www-data:www-data "${DOC_ROOT}"
  chmod -R 755 "${DOC_ROOT}"
fi

# 6. Configurar DocumentRoot do Apache2 e gerar proxy.pac (Proxy Auto-Config)
echo ""
echo "[6/8] Configurando Apache2 (DocumentRoot -> ${DOC_ROOT}) e proxy.pac..."
if [ ! -f /etc/apache2/sites-available/000-default.conf.bak ]; then
  cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
fi
sed -E "s|^([[:space:]]*DocumentRoot[[:space:]]+).*|\1${DOC_ROOT}|" \
  /etc/apache2/sites-available/000-default.conf.bak > /etc/apache2/sites-available/000-default.conf

# Detectar o IP local da VM pertencente a SUBREDE (ex.: 192.168.56.x)
PREFIXO_REDE="$(echo "${SUBREDE}" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3"."}')"
VM_IP="$(ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -F "${PREFIXO_REDE}" | head -n 1 || true)"
if [ -z "${VM_IP}" ]; then
  VM_IP="$(hostname -I | awk '{print $1}')"
fi

if [ -n "${VM_IP}" ] && [ -d "${DOC_ROOT}" ]; then
  cat > "${DOC_ROOT}/proxy.pac" << EOF
function FindProxyForURL(url, host) {
    if (isPlainHostName(host) ||
        shExpMatch(host, "localhost") ||
        shExpMatch(host, "127.0.0.1") ||
        shExpMatch(host, "${VM_IP}")) {
        return "DIRECT";
    }
    return "PROXY ${VM_IP}:3128";
}
EOF
  chown www-data:www-data "${DOC_ROOT}/proxy.pac"
  chmod 644 "${DOC_ROOT}/proxy.pac"
  echo "  -> proxy.pac gerado em ${DOC_ROOT}/proxy.pac (IP: ${VM_IP})"
fi

cat > /etc/apache2/conf-available/proxy-pac.conf << 'EOF'
AddType application/x-ns-proxy-autoconfig .pac
EOF
a2enconf proxy-pac >/dev/null 2>&1 || true

apache2ctl configtest
systemctl restart apache2
systemctl is-active --quiet apache2 && echo "  -> Apache2 ativo (running)!"

# 7. Configurar sudoers para www-data rodar sort e squid -k reconfigure
echo ""
echo "[7/8] Configurando /etc/sudoers.d/squidadmin..."
cat > /etc/sudoers.d/squidadmin << 'EOF'
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
chmod 440 /etc/sudoers.d/squidadmin
visudo -cf /etc/sudoers.d/squidadmin
sudo -u www-data sudo /usr/sbin/squid -k reconfigure && echo "  -> Permissao sudoers do www-data validada!"

# 8. Firewall UFW (apenas se estiver ativo)
echo ""
echo "[8/8] Verificando firewall UFW..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow from "${SUBREDE}" to any port 22 proto tcp
  ufw allow from "${SUBREDE}" to any port 80 proto tcp
  ufw allow from "${SUBREDE}" to any port 3128 proto tcp
  echo "  -> Portas 22, 80 e 3128 liberadas apenas para ${SUBREDE}."
else
  echo "  -> UFW inativo (nenhuma regra extra necessaria)."
fi

# Testes locais finais
echo ""
echo "============================================================"
echo " Testes locais automaticos"
echo "============================================================"
echo "--- Teste Proxy Squid (127.0.0.1:3128 -> example.com) ---"
curl -sI -x http://127.0.0.1:3128 http://example.com | head -n 5 || true

echo ""
echo "--- Teste Controlador Web (127.0.0.1/index.php) ---"
curl -sI http://127.0.0.1/index.php | head -n 5 || true

echo ""
echo "--- Teste Proxy Auto-Config (127.0.0.1/proxy.pac) ---"
curl -sI http://127.0.0.1/proxy.pac | head -n 5 || true

echo ""
echo "============================================================"
echo " CONCLUIDO!"
echo " IPs desta VM:"
ip -4 -brief addr
echo ""
echo " Painel Web : http://${VM_IP:-<IP_DA_VM>}/index.php"
echo " Script PAC : http://${VM_IP:-<IP_DA_VM>}/proxy.pac"
echo " Login      : user  (padrao de laboratorio em valida_login.php)"
echo " Proxy      : ${VM_IP:-<IP_DA_VM>} porta 3128"
echo "============================================================"
