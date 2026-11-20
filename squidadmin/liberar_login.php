<?php
include "valida.php";
require_once "normaliza_acl.php";

$local = "/etc/squid/acls/liberados/logins";
if (count($_POST) > 0 && isset($_POST['arquivo'])) {
  gravar_lista_acl($local, $_POST['arquivo'], 'logins');
}
$conteudo = ler_lista_acl($local);
?>

<?php require('cabecalho.php'); ?>

<h3>Liberar Logins</h3>

<div class="text">
<p>
Área destinada a liberar logins.<br />
Todos os logins listados aqui poderão ter acesso livre a qualquer site bloqueado (requer autenticação <code>auth_param</code> ativa no Squid).
</p>
</div>

<form name="liberar_logins" id="liberar_logins" action="" method="post">
  <textarea name="arquivo" id="arquivo" cols="75" rows="10"><?php echo htmlspecialchars($conteudo, ENT_QUOTES, 'UTF-8'); ?></textarea>
  <p><input type="submit" name="alterar" value="Alterar" id="alterar" /></p>
</form>

<?php require('rodape.php'); ?>
