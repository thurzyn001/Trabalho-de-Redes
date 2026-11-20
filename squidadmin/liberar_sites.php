<?php
include "valida.php";
require_once "normaliza_acl.php";

$local = "/etc/squid/acls/liberados/dominios";
if (count($_POST) > 0 && isset($_POST['arquivo'])) {
  gravar_lista_acl($local, $_POST['arquivo'], 'dominios');
}
$conteudo = ler_lista_acl($local);
?>

<?php require('cabecalho.php'); ?>

<h3>Liberar Sites</h3>

<div class="text">
<p>
Área destinada à liberação de sites (exceções).<br />
Todos os sites listados aqui serão liberados mesmo se estiverem em bloqueios.<br />
<small>Dica: informe um domínio por linha (ex.: <code>example.com</code>) ou cole a URL completa — o painel normaliza automaticamente.</small>
</p>
</div>

<form name="liberar_sites" id="liberar_sites" action="" method="post">
  <textarea name="arquivo" id="arquivo" cols="75" rows="10"><?php echo htmlspecialchars($conteudo, ENT_QUOTES, 'UTF-8'); ?></textarea>
  <p><input type="submit" name="alterar" value="Alterar" id="alterar" /></p>
</form>

<?php require('rodape.php'); ?>
