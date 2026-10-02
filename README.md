# docker-php-fpm-nginx

Imagem base dos projetos PHP da Multintegrada, montada como os servidores do Forge: **Ubuntu 24.04 + PHP 8.2 do `ppa:ondrej/php`**. Publicada no GitHub Container Registry, como pacote **privado**.

| Tag | Estágio | Conteúdo | Uso |
|---|---|---|---|
| `ghcr.io/multintegradabr/php-fpm-nginx:8.2-app` | `app` | PHP 8.2 (CLI + FPM), nginx, supervisor, cron, Node 22, Composer, gh | Ambiente local dos projetos |
| `ghcr.io/multintegradabr/php-fpm-nginx:8.2-ci` | `ci` | PHP 8.2 CLI, Composer, pcov (desligado), cliente do Postgres | Testes no CI (runner self-hosted) |

Cada build também publica tags fixas: `8.2-<estágio>-<AAAAMMDD>` e `8.2-<estágio>-<sha>`.

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

## Estágio `ci`

- Não fixa usuário: o job define o uid com `--user`, para casar com o dono do workspace no runner.
- `COMPOSER_HOME=/tmp/composer`, então funciona com qualquer uid.
- Cobertura: `php -d extension=pcov -d pcov.enabled=1 ...`.

## Build local

```bash
docker build --target app -t php-fpm-nginx:8.2-app .
docker build --target ci  -t php-fpm-nginx:8.2-ci .
```

O workflow `.github/workflows/build.yml` faz build e smoke test em todo PR. Em push na branch padrão, toda segunda-feira (patches de segurança) e sob demanda, ele também publica as tags e aplica a retenção de versões.
