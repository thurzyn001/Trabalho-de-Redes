<?php
include "valida.php";
require_once "normaliza_acl.php";

$local = "/etc/squid/acls/bloqueados/palavras";
if (count($_POST) > 0 && isset($_POST['arquivo'])) {
  gravar_lista_acl($local, $_POST['arquivo'], 'palavras');
}
$conteudo = ler_lista_acl($local);
?>

<?php require('cabecalho.php'); ?>

<h3>Bloquear Palavras</h3>

<div class="text">
<p>
Área destinada ao bloqueio de palavras presentes na URL (uma palavra por linha).<br />
&nbsp;</p>
</div>

<form name="bloquear_palavras" id="bloquear_palavras" action="" method="post">
  <textarea name="arquivo" id="arquivo" cols="75" rows="10"><?php echo htmlspecialchars($conteudo, ENT_QUOTES, 'UTF-8'); ?></textarea>
  <p><input type="submit" name="alterar" value="Alterar" id="alterar" /></p>
</form>

<?php require('rodape.php'); ?>
