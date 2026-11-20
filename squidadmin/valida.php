<?php



    // Inicia uma sessão

    session_start();



    // Verifica se as variaveis de sessão com o dn e a senha

    // existem. Caso existem, as variaveis $dn e $senha recebem os valores



    if (IsSet($_SESSION["senha"]))

        $senha = $_SESSION["senha"];

	else

		$senha = "1";



    if (IsSet($_SESSION["nomeval"]))

        $nomeval = $_SESSION["nomeval"];

	else

		$nomeval = 1;



//echo $nomeval; 

//echo $senha;



	if ($nomeval==1 and $senha==1)

    {

		unset ($_SESSION["senha"]);

		unset ($_SESSION["nomeval"]);

		echo("<hr />A senha ou login digitado estao incorretos. Tente novamente. <hr /><a href='index.php'>Login</a>");

		exit;

    }

    

    // include "valida.php";

?>

