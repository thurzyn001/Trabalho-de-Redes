<?php



    // Termina a sessão e volta para a página de login

    session_start();  

    $_SESSION = array();

    session_destroy();



    // Redireciona para pagina principal

    header ("Location: index.php");



 ?>

