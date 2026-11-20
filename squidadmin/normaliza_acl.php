<?php
/**
 * Higieniza e normaliza listas de ACL antes de gravar em /etc/squid/acls/.
 * - Remove quebras CRLF (\r), espaços extras, duplicatas e linhas vazias.
 * - Para 'dominios': extrai somente o domínio (remove http://, https://,
 *   caminhos /..., portas e prefixo www.), garantindo bloqueio em HTTP e HTTPS (CONNECT).
 */
function normalizar_lista_acl($texto, $tipo = 'generico') {
    $texto = str_replace("\r\n", "\n", (string)$texto);
    $texto = str_replace("\r", "\n", $texto);
    $linhas = explode("\n", $texto);
    $resultado = array();

    foreach ($linhas as $linha) {
        $item = trim($linha);
        if ($item === '') {
            continue;
        }

        if ($tipo === 'dominios') {
            $item = strtolower($item);
            if (strpos($item, '://') !== false) {
                $host = parse_url($item, PHP_URL_HOST);
                if (!empty($host)) {
                    $item = $host;
                }
            } else {
                $item = preg_replace('#/.*$#', '', $item);
                $item = preg_replace('#:\d+$#', '', $item);
            }
            $item = ltrim($item, '.');
            if (strpos($item, 'www.') === 0 && substr_count($item, '.') >= 2) {
                $item = substr($item, 4);
            }
            $item = trim($item);
            if ($item === '') {
                continue;
            }
        }

        $resultado[$item] = true;
    }

    $lista = array_keys($resultado);
    sort($lista, SORT_STRING);
    return count($lista) > 0 ? implode("\n", $lista) . "\n" : "";
}

function gravar_lista_acl($local, $conteudo_post, $tipo = 'generico') {
    $conteudo = normalizar_lista_acl($conteudo_post, $tipo);
    $arquivo = fopen($local, "w+");
    if ($arquivo !== false) {
        fwrite($arquivo, $conteudo);
        fclose($arquivo);
    }
    exec("sudo /usr/bin/sort " . escapeshellarg($local) . " -o " . escapeshellarg($local));
    exec("sudo /usr/sbin/squid -k reconfigure");
}

function ler_lista_acl($local) {
    if (!is_readable($local)) {
        return "";
    }
    $conteudo = file_get_contents($local);
    return $conteudo === false ? "" : $conteudo;
}
?>
