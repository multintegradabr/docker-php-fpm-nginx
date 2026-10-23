<?php

declare(strict_types=1);

function gdCheck(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

gdCheck(gd_info()['AVIF Support'] ?? false, 'GD precisa manter suporte AVIF');
$directory = sys_get_temp_dir().'/gd-avif-smoke-'.bin2hex(random_bytes(8));
gdCheck(mkdir($directory, 0700), 'Não foi possível criar o diretório de teste');
$image = imagecreatetruecolor(32, 24);
$samples = [
    [4, 4, [255, 0, 0]],
    [26, 4, [0, 255, 0]],
    [4, 18, [0, 0, 255]],
    [26, 18, [255, 255, 255]],
];
foreach ($samples as [$x, $y, [$red, $green, $blue]]) {
    imagefilledrectangle($image, $x < 16 ? 0 : 16, $y < 12 ? 0 : 12,
        $x < 16 ? 15 : 31, $y < 12 ? 11 : 23,
        imagecolorallocate($image, $red, $green, $blue));
}
try {
    foreach ([
        ['avif', 'imageavif', 'imagecreatefromavif', 100],
        ['png', 'imagepng', 'imagecreatefrompng', 6],
        ['jpg', 'imagejpeg', 'imagecreatefromjpeg', 100],
    ] as [$extension, $encode, $decode, $quality]) {
        $file = $directory.'/fixture.'.$extension;
        gdCheck($encode($image, $file, $quality), 'Falha ao codificar '.$extension);
        gdCheck(filesize($file) > 0, 'Arquivo vazio: '.$extension);
        $decoded = $decode($file);
        gdCheck($decoded !== false, 'Falha ao decodificar '.$extension);
        gdCheck(imagesx($decoded) === 32 && imagesy($decoded) === 24, 'Dimensões divergentes');
        foreach ($samples as [$x, $y, $expected]) {
            $pixel = imagecolorsforindex($decoded, imagecolorat($decoded, $x, $y));
            foreach (['red', 'green', 'blue'] as $channel => $name) {
                gdCheck(abs($pixel[$name] - $expected[$channel]) <= 20,
                    'Cor divergente em '.$extension.'/'.$name);
            }
        }
        imagedestroy($decoded);
    }
    echo 'GD: encode/decode AVIF, PNG e JPEG com dimensões e cores preservadas.'.PHP_EOL;
} finally {
    imagedestroy($image);
    foreach (glob($directory.'/*') as $file) {
        unlink($file);
    }
    rmdir($directory);
}
