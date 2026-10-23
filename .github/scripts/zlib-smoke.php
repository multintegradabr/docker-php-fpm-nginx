<?php

// Compatibilidade dos consumidores PHP da libz compartilhada; não é PoC do CVE.
declare(strict_types=1);

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$directory = sys_get_temp_dir().'/zlib-smoke-'.bin2hex(random_bytes(8));
check(mkdir($directory, 0700), 'Não foi possível criar o diretório de teste');
try {
    foreach (['', str_repeat('zlib fixture '."\0\xff", 20000), random_bytes(262144)] as $index => $input) {
        check(gzuncompress(gzcompress($input)) === $input, 'Round-trip zlib falhou');
        check(gzdecode(gzencode($input)) === $input, 'Round-trip gzip falhou');
        check(gzinflate(gzdeflate($input)) === $input, 'Round-trip deflate falhou');

        $file = $directory.'/stream-'.$index.'.gz';
        $stream = gzopen($file, 'wb');
        check($stream !== false, 'Falha ao abrir stream gzip');
        foreach (str_split($input, 4096) as $chunk) {
            check(gzwrite($stream, $chunk) === strlen($chunk), 'Escrita parcial no gzip');
        }
        check(gzclose($stream), 'Falha ao fechar stream gzip');
        check(file_get_contents('compress.zlib://'.$file) === $input, 'Leitura do stream gzip falhou');

        $archive = new ZipArchive();
        $zipFile = $directory.'/archive-'.$index.'.zip';
        check($archive->open($zipFile, ZipArchive::CREATE) === true, 'Falha ao criar ZIP');
        check($archive->addFromString('fixture.bin', $input), 'Falha ao adicionar entrada ZIP');
        check($archive->setCompressionName('fixture.bin', ZipArchive::CM_DEFLATE), 'Falha ao selecionar deflate');
        check($archive->close(), 'Falha ao fechar ZIP');
        check($archive->open($zipFile, ZipArchive::CHECKCONS) === true, 'ZIP inconsistente');
        check($archive->getFromName('fixture.bin') === $input, 'Conteúdo ZIP divergente');
        $archive->close();
    }
    echo 'zlib PHP '.ZLIB_VERSION.': gzip, deflate, streams e ZIP passaram (vazio, repetitivo e binário).'.PHP_EOL;
} finally {
    foreach (glob($directory.'/*') as $file) {
        unlink($file);
    }
    rmdir($directory);
}
