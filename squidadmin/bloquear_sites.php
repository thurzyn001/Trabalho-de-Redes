<?php
include "valida.php";
require_once "normaliza_acl.php";

$local = "/etc/squid/acls/bloqueados/dominios";
if (count($_POST) > 0 && isset($_POST['arquivo'])) {
  gravar_lista_acl($local, $_POST['arquivo'], 'dominios');
}
$conteudo = ler_lista_acl($local);
?>

<?php require('cabecalho.php'); ?>

<h3>Bloquear Sites</h3>

<div class="text">
<p>
Área destinada ao bloqueio de sites.<br />
Todos os sites listados aqui não poderão ser acessados (HTTP e HTTPS).<br />
<small>Dica: informe um domínio por linha (ex.: <code>youtube.com</code>) ou cole a URL completa — o painel normaliza automaticamente.</small>
</p>
</div>

<form name="bloquear_sites" id="bloquear_sites" action="" method="post">
  <textarea name="arquivo" id="arquivo" cols="75" rows="10"><?php echo htmlspecialchars($conteudo, ENT_QUOTES, 'UTF-8'); ?></textarea>
  <p><input type="submit" name="alterar" value="Alterar" id="alterar" /></p>
</form>

<?php require('rodape.php'); ?>
