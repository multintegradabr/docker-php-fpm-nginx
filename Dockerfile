# syntax=docker/dockerfile:1.7
#
# Imagem base dos projetos PHP da Multintegrada, montada como os servidores do Forge:
# Ubuntu 24.04 + PHP do ppa:ondrej. Três estágios:
#   base: PHP CLI com as extensões, Composer e o usuário multi (uid 1000)
#   ci:   base + pcov (desligado), cliente do Postgres, Python e zstd para o CI
#   app:  base + php-fpm, nginx, supervisor, cron e Node, para o ambiente local

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS libavif-security
COPY .docker/libavif /usr/local/src/libavif-security
RUN sh /usr/local/src/libavif-security/build.sh

FROM ubuntu:${UBUNTU_VERSION} AS base

ARG PHP_VERSION=8.2

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Fortaleza \
    PHP_VERSION=${PHP_VERSION} \
    COMPOSER_ALLOW_SUPERUSER=1

LABEL org.opencontainers.image.source="https://github.com/multintegradabr/docker-php-fpm-nginx" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} em Ubuntu, no mesmo padrão dos servidores do Forge"

# Muda a cada dia no CI. Sem isso, o cache do build reaproveita a camada do apt e a imagem
# segue com o PHP antigo enquanto a ubuntu:24.04 não mudar (21/10/2026: 8.2.34 vulnerável).
ARG APT_REFRESH=""

COPY --from=libavif-security /packages/*.deb /tmp/libavif-security/

RUN echo "apt refresh: ${APT_REFRESH}" \
    && apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git gnupg software-properties-common tzdata unzip zip zlib1g \
    # CVE-2026-85091: backport oficial do Ubuntu 24.04; falha se o mirror/cache estiver antigo.
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' zlib1g)" ge '1:1.3.dfsg-3.1ubuntu2.3' \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    # A partir do 8.5 o opcache é parte do PHP e o ppa:ondrej não tem mais o pacote php8.5-opcache.
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-cli php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-readline php${PHP_VERSION}-redis php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        $(dpkg --compare-versions "${PHP_VERSION}" lt 8.5 && echo php${PHP_VERSION}-opcache) \
    # Backport local explícito, construído e testado a partir do source package Ubuntu.
    # Se um pacote oficial mais novo conflitar, falhar em vez de fazer downgrade.
    && apt-get install -y --no-install-recommends /tmp/libavif-security/*.deb \
    # Usado somente para cadastrar o PPA; remove também os auxiliares Python/Polkit.
    && apt-get purge -y --auto-remove software-properties-common \
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

# session.sid_length e session.sid_bits_per_character são deprecated desde o 8.4 e geram um aviso
# a cada execução do php.
RUN if dpkg --compare-versions "${PHP_VERSION}" ge 8.4; then \
        sed -i '/^session\.sid_\(length\|bits_per_character\) /d' /etc/php/${PHP_VERSION}/cli/conf.d/99-custom.ini; \
    fi

WORKDIR /var/www

# ---------------------------------------------------------------------------------------------

FROM base AS ci

RUN apt-get update \
    # Os relatórios de testes/cobertura usam Python e sua biblioteca padrão.
    # Dependência explícita: o bootstrap do PPA é removido no estágio base.
    && apt-get install -y --no-install-recommends php${PHP_VERSION}-pcov postgresql-client python3 zstd \
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

COPY .docker/apt/nginx.asc /usr/share/keyrings/nginx.asc

# Pacotes stable do fornecedor: 1.30.6 corrige os avisos recentes do Nginx.
# A chave pública revisada fica no repo; APT valida assinatura e hashes dos pacotes.
RUN . /etc/os-release \
    && printf 'deb [signed-by=/usr/share/keyrings/nginx.asc] https://nginx.org/packages/ubuntu %s nginx\n' "$VERSION_CODENAME" > /etc/apt/sources.list.d/nginx.list \
    && printf 'Package: nginx nginx-module-*\nPin: origin nginx.org\nPin-Priority: 900\n' > /etc/apt/preferences.d/99nginx \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-fpm nginx supervisor cron sudo nano htop postgresql-client \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' nginx)" ge 1.30.6 \
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

RUN sed -i "s/@PHP_VERSION@/${PHP_VERSION}/g" \
        /etc/php/${PHP_VERSION}/fpm/php-fpm.conf /etc/supervisor/conf.d/php-nginx.conf \
    && if dpkg --compare-versions "${PHP_VERSION}" ge 8.4; then \
        sed -i '/^session\.sid_\(length\|bits_per_character\) /d' /etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini; \
    fi \
    && rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf \
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
