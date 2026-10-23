# docker-php-fpm-nginx

Imagem base dos projetos PHP da Multintegrada, montada como os servidores do Forge: **Ubuntu 24.04 + PHP 8.2 do `ppa:ondrej/php`**. Publicada no GitHub Container Registry, como pacote **privado**.

| Tag | Estágio | Conteúdo | Uso |
|---|---|---|---|
| `ghcr.io/multintegradabr/php-fpm-nginx:8.2-app` | `app` | PHP 8.2 (CLI + FPM), nginx, supervisor, cron, Node 22, Composer, gh | Ambiente local dos projetos |
| `ghcr.io/multintegradabr/php-fpm-nginx:8.2-ci` | `ci` | PHP 8.2 CLI, Composer, pcov (desligado), cliente do Postgres, Python 3, zstd | Testes no CI (runner self-hosted) |

Cada build também publica tags fixas: `8.2-<estágio>-<AAAAMMDD>` e `8.2-<estágio>-<sha>`.

## Piso de segurança do zlib

O estágio `base`, compartilhado por `app` e `ci`, exige `zlib1g` no mínimo
`1:1.3.dfsg-3.1ubuntu2.3`. Esse é o pacote que a
[Canonical identifica como corrigido para CVE-2026-85091 no Ubuntu 24.04](https://ubuntu.com/security/CVE-2026-85091).
O APT continua obtendo as atualizações assinadas dos repositórios Ubuntu; não
há biblioteca compilada localmente ou pacote de outra distribuição.

O build atualiza o sistema e falha se o mirror/cache só fornecer uma versão
anterior ao piso. O smoke do CI repete essa verificação em ambos os estágios e,
como UID 1001 sem acesso à rede, testa gzip, deflate, streams gzip e ZIP no PHP
com dados vazios, repetitivos e binários. São testes de compatibilidade dos
consumidores da biblioteca, não uma reprodução do exploit.

Como a correção é um backport, a versão upstream exibida pelo PHP pode continuar
em 1.3; a verificação usa a versão completa do pacote Debian/Ubuntu. O piso deve
ser revisto junto com o status do fornecedor ao mudar a versão base do Ubuntu.
Os relatórios OSV continuam completos, sem ignores.

## Acesso (pacote privado)

Faça login no GHCR com o seu usuário do GitHub. O token precisa do escopo `read:packages`:

```bash
gh auth refresh -s read:packages
gh auth token | docker login ghcr.io -u <seu-usuario-github> --password-stdin
```

Para um workflow de outro repositório baixar a imagem, libere o repositório em *Package settings → Manage Actions access* e use no job:

```yaml
permissions:
  packages: read
container:
  image: ghcr.io/multintegradabr/php-fpm-nginx:8.2-ci
  credentials:
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

## Estágio `app`

- Usuário `multi` (uid 1000) com sudo; código em `/var/www`; php-fpm no socket `/run/php/php-fpm.sock`.
- As configs de nginx, php-fpm e supervisor entram no lugar durante o build. O `entrypoint.sh` só cuida do que depende do ambiente:
  - opcache de produção quando roda no Azure App Service;
  - agente do Datadog (`DATADOG_ENABLE=true` + `DD_API_KEY`);
  - credenciais do git (`GH_TOKEN`);
  - workers da fila e post-init quando existe `artisan`;
  - crontab e scripts em `/home/multi/startup.d`.
- O entrypoint é idempotente: o container pode reiniciar sem problema.
- A imagem não inclui servidor SSH.

### Atualizações do Nginx

O estágio `app` usa o canal **stable oficial do nginx.org** para Ubuntu, com
prioridade APT limitada a `nginx`/`nginx-module-*`. O build exige no mínimo
**1.30.6** e continua recebendo versões stable mais recentes nos rebuilds.
O Ubuntu, PHP/PPA, Node e a imagem `ci` mantêm suas origens anteriores.
O site de exemplo do pacote oficial é removido; as configurações do projeto
continuam em `/etc/nginx/sites-enabled`.

Segundo os [avisos oficiais](https://nginx.org/en/security_advisories.html),
1.30.6 corrige CVE-2026-15176 (alias/rewrite), CVE-2026-97629 (tickets TLS) e
CVE-2026-97205 (AIO), presentes no relatório OSV da imagem com Nginx 1.24.
A exploração depende da configuração. Outros três avisos daquele relatório
(CVE-2026-93479, CVE-2026-95101 e CVE-2026-90439) têm intervalos upstream que
começam depois de 1.24; não são contabilizados como correções desta atualização.
O scanner continua analisando a imagem completa, sem ignores. Uma troca de
origem do pacote não deve ser interpretada por si só como eliminação dos alertas.

Na validação com OSV-Scanner 2.7.0, a imagem candidata passou de 155 para 152 IDs
distintos. A redução veio da ausência de `iproute2` e de suas dependências
`libbpf1`/`libelf1t64`, que o pacote oficial do Nginx não exige: saíram
UBUNTU-CVE-2025-29481, UBUNTU-CVE-2025-1352 e UBUNTU-CVE-2025-1376.
Não surgiram IDs novos. Os seis avisos de Nginx continuam classificados pelo
scanner como Ubuntu:24.04 mesmo em 1.30.6-1~noble; os intervalos corrigidos
upstream e a pendência de classificação devem ser considerados separadamente.

A chave pública `.docker/apt/nginx.asc` veio de
<https://nginx.org/keys/nginx_signing.key>, conforme as
[instruções oficiais](https://nginx.org/en/linux_packages.html#Ubuntu).
O APT verifica assinaturas e hashes usando apenas esse keyring para essa origem.
Fingerprints revisados:

- `8540A6F18833A80E9C1653A42FD21310B49F6B46`
- `573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62`
- `9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3`

Revisar esses fingerprints na fonte oficial ao atualizar o arquivo por rotação
ou expiração. O SHA-256 do arquivo inicial é
`55385da31d198fa6a5012d40ae98ecb272a6c4e8fffffba94719ffd3e87de37a`.

Além dos testes de extensões e configuração, o CI inicia o entrypoint real em
container descartável sem rede externa e verifica supervisor/Nginx/PHP-FPM,
rota com query string, estáticos/cache, bloqueio de arquivos ocultos e HTTPS/HTTP2
com certificado temporário. Para repetir após o build:

```bash
docker run --rm --network none --user root --entrypoint sh \
  -v "$PWD/.github/scripts/app-web-smoke.sh:/tmp/app-web-smoke.sh:ro" \
  php-fpm-nginx:8.2-app /tmp/app-web-smoke.sh
```

## Estágio `ci`

- Inclui Python 3 e sua biblioteca padrão para os scripts de métricas, cobertura e relatórios de segurança dos projetos consumidores. A instalação é explícita e não depende dos pacotes temporários de cadastro do PPA.

- Inclui `zstd`, `zstdmt` e `unzstd`: o `actions/cache` seleciona zstd automaticamente quando o programa está disponível.
- A primeira execução com zstd precisa criar um cache novo: o formato faz parte da versão interna do cache. Depois da publicação da imagem, rode o workflow de testes na branch principal dos projetos consumidores para aquecer o cache compartilhado com os PRs.
- Não fixa usuário: o job define o uid com `--user`, para casar com o dono do workspace no runner.
- `HOME=/tmp`, então git e Composer funcionam com qualquer uid.
- Cobertura: `php -d extension=pcov -d pcov.enabled=1 ...`.

## Build local

```bash
docker build --target app -t php-fpm-nginx:8.2-app .
docker build --target ci  -t php-fpm-nginx:8.2-ci .
```

O workflow `.github/workflows/build.yml` faz build e smoke test em todo PR. Em push na branch padrão, toda segunda-feira (patches de segurança) e sob demanda, ele também publica as tags e aplica a retenção de versões.
