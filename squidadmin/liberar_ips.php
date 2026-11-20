<?php
include "valida.php";
require_once "normaliza_acl.php";

$local = "/etc/squid/acls/liberados/ips";
if (count($_POST) > 0 && isset($_POST['arquivo'])) {
  gravar_lista_acl($local, $_POST['arquivo'], 'ips');
}
$conteudo = ler_lista_acl($local);
?>

<?php require('cabecalho.php'); ?>

<h3>Liberar IPs</h3>

<div class="text">
<p>
Área destinada a liberar IPs (um IP por linha, ex.: <code>192.168.56.10</code>).<br />
Todos os IPs listados aqui terão acesso livre, ignorando os bloqueios de sites e palavras.
</p>
</div>

<form name="liberar_ips" id="liberar_ips" action="" method="post">
  <textarea name="arquivo" id="arquivo" cols="75" rows="10"><?php echo htmlspecialchars($conteudo, ENT_QUOTES, 'UTF-8'); ?></textarea>
  <p><input type="submit" name="alterar" value="Alterar" id="alterar" /></p>
</form>

<?php require('rodape.php'); ?>
