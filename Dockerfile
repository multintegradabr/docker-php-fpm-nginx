# syntax=docker/dockerfile:1.7
#
# Imagem base dos projetos PHP da Multintegrada, montada como os servidores do Forge:
# Ubuntu 24.04 + PHP do ppa:ondrej. Três estágios:
#   base: PHP CLI com as extensões, Composer e o usuário multi (uid 1000)
#   ci:   base + pcov (desligado) e cliente do Postgres, para rodar testes no CI
#   app:  base + php-fpm, nginx, supervisor, cron e Node, para o ambiente local

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS base

ARG PHP_VERSION=8.2

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Fortaleza \
    PHP_VERSION=${PHP_VERSION} \
    COMPOSER_ALLOW_SUPERUSER=1

LABEL org.opencontainers.image.source="https://github.com/multintegradabr/docker-php-fpm-nginx" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} em Ubuntu, no mesmo padrão dos servidores do Forge"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git gnupg software-properties-common tzdata unzip zip \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-cli php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-opcache php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-readline php${PHP_VERSION}-redis php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# O ubuntu:24.04 já vem com o usuário "ubuntu" no uid 1000, que é o uid do multi.
RUN userdel --remove ubuntu \
    && groupadd --gid 1000 multi \
    && useradd --uid 1000 --gid multi --create-home --shell /bin/bash multi \
    && mkdir -p /var/www && chown multi:multi /var/www

COPY .docker/php/php-fpm/custom.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-custom.ini

WORKDIR /var/www

# ---------------------------------------------------------------------------------------------

FROM base AS ci

RUN apt-get update \
    && apt-get install -y --no-install-recommends php${PHP_VERSION}-pcov postgresql-client \
    && phpdismod -v ${PHP_VERSION} -s cli pcov \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# A suíte do SI recria a aplicação a cada teste e relê as rotas, o cache de rotas (2,5 MB) e
# as views compiladas. Sem opcache no CLI cada require refaz o parse: com ele ligado, o
# CI do SI (08/10, 2 jobs simultâneos): "Execute tests" de 319 s para 230 s junto com o route:cache.
# revalidate_freq=0 confere o mtime a cada require, para um arquivo reescrito no meio da
# suíte (view compilada, cache de rotas) não rodar o opcode antigo.
RUN printf 'opcache.enable_cli=1\nopcache.revalidate_freq=0\n' > /etc/php/${PHP_VERSION}/cli/conf.d/99-ci-opcache.ini

# Sem USER fixo: o job do CI define o uid com --user, para casar com o dono do workspace no host.
# Esse uid não existe no /etc/passwd, e o HOME padrão (/) não é gravável para o git do checkout.
ENV HOME=/tmp

# ---------------------------------------------------------------------------------------------

FROM base AS app

ARG NODE_MAJOR=22

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-fpm nginx supervisor cron sudo nano htop postgresql-client \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# O entrypoint e os scripts de init dos projetos usam sudo como multi.
RUN echo "multi ALL=NOPASSWD: ALL" > /etc/sudoers.d/multi && chmod 0440 /etc/sudoers.d/multi

# Configs no lugar já no build: o entrypoint só cuida do que depende do ambiente.
COPY .docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY .docker/nginx/default.conf /etc/nginx/sites-enabled/default.conf
COPY .docker/php/php-fpm/php-fpm.conf /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
COPY .docker/php/php-fpm/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
COPY .docker/php/php-fpm/custom.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini
COPY .docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY .docker/supervisor/php-nginx.conf /etc/supervisor/conf.d/php-nginx.conf
COPY .docker /usr/local/docker

RUN rm -f /etc/nginx/sites-enabled/default \
    && rm -rf /var/www/html \
    && mkdir -p /etc/nginx/ssl /run/php /var/log/php /home/multi/LogFiles \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && chown -R multi:multi /run/php /var/log/php /home/multi /usr/local/docker /var/www \
    && chmod +x /usr/local/docker/cron/php-schedule.sh /usr/local/docker/startup/*.sh

COPY --chmod=775 entrypoint.sh /bin/entrypoint.sh

EXPOSE 80 443

USER multi:multi

ENTRYPOINT ["sudo", "-E", "/bin/entrypoint.sh"]
