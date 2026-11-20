<?php





    // Recebe os valores do formulário

	$login		= $_POST["login"];

    $senha		= $_POST["senha"];  



    // Verifica se o usuario digitou a senha correta e se o mesmo tem permissao para verificar relatorios

    if ($login=="user" and $senha=="@@1234!!aabbcc")

    {

		session_start();

		$_SESSION["nomeval"] 		= $login;

		$_SESSION["senha"]		= $senha;



		header ("Location: inicio.php");

    }

    else

		echo("<hr />A senha ou login digitados est&atilde;o incorretos, ou ent&atilde;o o usu&aacute;rio n&atilde;o tem permiss&otilde;es. Tente novamente. <hr /><a href='index.php'>Login</a>");
  
?>

