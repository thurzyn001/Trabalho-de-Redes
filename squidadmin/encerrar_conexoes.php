<?php
include "valida.php";

$mensagem = "";
$sucesso = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['acao']) && $_POST['acao'] === 'flush_squid') {
  $saida = array();
  $codigo = 0;
  exec("sudo /usr/bin/systemctl restart squid 2>&1", $saida, $codigo);
  if ($codigo === 0) {
    $sucesso = true;
    $mensagem = "Squid reiniciado com sucesso! Todos os túneis TCP/HTTPS ativos foram encerrados e as novas regras já valem imediatamente.";
  } else {
    $mensagem = "Não foi possível reiniciar o Squid (código " . intval($codigo) . "). Verifique a permissão sudoers em /etc/sudoers.d/squidadmin.";
  }
}
?>

<?php require('cabecalho.php'); ?>

<h3>Derrubar Conexões Ativas (Flush no Servidor Squid)</h3>

<div class="text">
<p>
Ao clicar em <strong>Alterar</strong> nas listas de bloqueio, o Squid recarrega as regras (<code>squid -k reconfigure</code>) para <strong>novas conexões</strong>, mas conexões HTTPS (<code>CONNECT</code>) que já estavam abertas no navegador — como uma aba aberta do YouTube — podem continuar ativas até expirarem.
</p>
<p>
Use o botão abaixo para <strong>reiniciar o Squid imediatamente</strong> (com <code>shutdown_lifetime 1 seconds</code>), derrubando todos os túneis TCP/HTTPS abertos no servidor e forçando os navegadores a passarem pelas novas regras:
</p>

<?php if ($mensagem !== ""): ?>
  <div class="aviso <?php echo $sucesso ? 'aviso-ok' : 'aviso-erro'; ?>">
    <?php echo htmlspecialchars($mensagem, ENT_QUOTES, 'UTF-8'); ?>
  </div>
<?php endif; ?>

<form method="post" action="">
  <input type="hidden" name="acao" value="flush_squid" />
  <p>
    <input type="submit" value="Reiniciar Squid e derrubar túneis ativos" class="btn-flush" />
  </p>
</form>

<div class="info-box">
  <strong>Por que o painel não consegue limpar os sockets/cache internos do Chrome sozinho?</strong>
  <p>
    Por segurança, navegadores modernos (Chrome, Edge, Firefox) <strong>impedem</strong> que qualquer página web limpe o cache local do navegador ou abra endereços internos como <code>chrome://...</code> via código JavaScript.
  </p>
  <p>
    Este botão resolve o lado do <strong>servidor</strong> (derruba túneis HTTPS já abertos no Squid). Se um site <strong>HTTP</strong> visitado há pouco continuar aparecendo por causa do <strong>cache local do navegador</strong>, recarregue com <strong>Ctrl + Shift + R</strong> ou cole no Chrome o endereço abaixo e clique em <em>Flush socket pools</em>:
  </p>
  <p>
    <input type="text" id="urlSockets" value="chrome://net-internals/#sockets" readonly size="34" />
    <button type="button" onclick="copiarUrlSockets()">Copiar endereço</button>
    <span id="msgCopiado" style="color: #0b6b2f; font-weight: bold; margin-left: 6px;"></span>
  </p>
</div>
</div>

<script>
function copiarUrlSockets() {
  var campo = document.getElementById('urlSockets');
  campo.select();
  campo.setSelectionRange(0, 99999);
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(campo.value);
  } else {
    document.execCommand('copy');
  }
  document.getElementById('msgCopiado').textContent = 'Copiado! Cole na barra do Chrome.';
}
</script>

<?php require('rodape.php'); ?>
