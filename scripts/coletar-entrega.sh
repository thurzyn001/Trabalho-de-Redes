#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Coletor automatico de arquivos para entrega do Trabalho de Redes
# Empacota: /etc/squid (squid.conf + acls), /etc/apache2 (HTTP), /etc/sudoers.d,
#           /var/www/squidadmin (index.php + painel), /var/log/squid/access.log
#           e evidencias de status dos servicos em um arquivo .zip limpo.
# Uso: sudo bash coletar-entrega.sh [NOME_DO_ZIP]
# ==============================================================================

if [ "${EUID}" -ne 0 ]; then
  echo "[ERRO] Execute este script com sudo: sudo bash $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
ZIP_NAME="${1:-entrega-trabalho-squid.zip}"
OUT_ZIP="${REAL_HOME}/${ZIP_NAME}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

if ! command -v zip >/dev/null 2>&1; then
  echo "[0/4] Instalando pacote 'zip'..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y zip >/dev/null
fi

echo "[1/4] Copiando configuracoes de /etc (Squid, ACLs, Apache2 HTTP, sudoers)..."
mkdir -p \
  "${STAGE}/etc/squid" \
  "${STAGE}/etc/apache2/sites-available" \
  "${STAGE}/etc/apache2/conf-available" \
  "${STAGE}/etc/sudoers.d"

[ -f /etc/squid/squid.conf ] && cp -a /etc/squid/squid.conf "${STAGE}/etc/squid/"
[ -d /etc/squid/acls ] && cp -a /etc/squid/acls "${STAGE}/etc/squid/"
[ -f /etc/apache2/sites-available/000-default.conf ] && cp -a /etc/apache2/sites-available/000-default.conf "${STAGE}/etc/apache2/sites-available/"
[ -f /etc/apache2/conf-available/proxy-pac.conf ] && cp -a /etc/apache2/conf-available/proxy-pac.conf "${STAGE}/etc/apache2/conf-available/"
[ -f /etc/sudoers.d/squidadmin ] && cp -a /etc/sudoers.d/squidadmin "${STAGE}/etc/sudoers.d/"

echo "[2/4] Copiando arquivos de /var (Controlador Web index.php e logs do Squid)..."
mkdir -p "${STAGE}/var/www" "${STAGE}/var/log/squid"
if [ -d /var/www/squidadmin ]; then
  cp -a /var/www/squidadmin "${STAGE}/var/www/"
elif [ -f /var/www/index.php ]; then
  cp -a /var/www/. "${STAGE}/var/www/"
fi
[ -f /var/log/squid/access.log ] && cp -a /var/log/squid/access.log "${STAGE}/var/log/squid/"

echo "[3/4] Gerando evidencias de execucao e LEIA-ME.txt..."
mkdir -p "${STAGE}/evidencias"
{
  echo "=== DATA DA COLETA ==="
  date
  echo ""
  echo "=== INTERFACES DE REDE ==="
  ip -4 -brief addr
  echo ""
  echo "=== VERSOES ==="
  squid -v 2>/dev/null | head -n 2 || true
  apache2 -v 2>/dev/null || true
  php -v 2>/dev/null | head -n 1 || true
  echo ""
  echo "=== VALIDACAO SQUID (squid -k parse) ==="
  squid -k parse 2>&1 || true
  echo ""
  echo "=== STATUS DOS SERVICOS ==="
  systemctl status squid --no-pager -l 2>/dev/null | head -n 15 || true
  echo ""
  systemctl status apache2 --no-pager -l 2>/dev/null | head -n 15 || true
  echo ""
  echo "=== ULTIMAS 30 LINHAS DO access.log ==="
  tail -n 30 /var/log/squid/access.log 2>/dev/null || true
} > "${STAGE}/evidencias/status-servicos.txt"

cat > "${STAGE}/LEIA-ME.txt" << 'EOF'
ENTREGA - TRABALHO DE REDES (SQUID PROXY + CONTROLADOR WEB APACHE2/PHP)
=======================================================================

Estrutura dos arquivos extraidos diretamente do servidor Ubuntu:

1. etc/squid/squid.conf
   - Configuracao principal do servidor proxy Squid (porta 3128) com ACLs
     integradas ao controlador Web e shutdown_lifetime configurado.

2. etc/squid/acls/bloqueados/ e etc/squid/acls/liberados/
   - Listas de dominios, palavras, IPs e logins gerenciadas pelo painel Web.

3. etc/apache2/sites-available/000-default.conf (e conf-available/proxy-pac.conf)
   - Configuracao HTTP do Apache2 apontando o DocumentRoot para o painel Web
     e MIME type do script de configuracao automatica proxy.pac.

4. etc/sudoers.d/squidadmin
   - Regra restrita que permite ao usuario www-data ordenar as listas e
     recarregar/reiniciar o Squid pelo painel Web.

5. var/www/squidadmin/ (index.php e demais paginas PHP + proxy.pac)
   - Codigo completo do controlador Web publicado no servidor HTTP.

6. var/log/squid/access.log
   - Log real de requisicoes passando pelo proxy (ex.: TCP_MISS/200,
     TCP_TUNNEL/200 e bloqueios TCP_DENIED/403).

7. evidencias/status-servicos.txt
   - Status dos servicos squid e apache2, versoes, validacao squid -k parse
     e resumo do access.log.
EOF

echo "[4/4] Gerando arquivo final ${OUT_ZIP}..."
rm -f "${OUT_ZIP}"
(cd "${STAGE}" && zip -rq "${OUT_ZIP}" .)
chown "${REAL_USER}:${REAL_USER}" "${OUT_ZIP}"
ls -lh "${OUT_ZIP}"
echo ""
echo "PRONTO! Baixe para o Windows com:"
echo "  scp ${REAL_USER}@<IP_DA_VM>:~/${ZIP_NAME} ."
