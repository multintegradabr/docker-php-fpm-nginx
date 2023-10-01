FROM php:8.2-fpm

ENV PATH ${PATH}:/var/www
ENV SSH_PASSWD "root:Docker!"
ENV NODE_MAJOR=16

# Essential SO configuration 
RUN echo "UTC-3" > /etc/timezone
RUN apt update && apt install -y tzdata
RUN ln -fs /usr/share/zoneinfo/America/Fortaleza /etc/localtime

# Set bash as default shell
RUN apt install bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /var/www" >> /etc/bash.bashrc

# Configuration for SSH Server
RUN apt install -y --no-install-recommends dialog \
  && apt update \
  && apt install -y --no-install-recommends openssh-server \
  && echo "$SSH_PASSWD" | chpasswd
COPY sshd_config /etc/ssh/

# Install essential Packages
RUN apt install -y \
  zip \
  grep \
  unzip \
  curl \
  supervisor \
  nano \
  wget \
  git \
  openssl \
  dialog \
  postgresql-client \
  htop \
  nginx \
  sudo \
  ca-certificates \
  cron

# Install Github CLI
RUN type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y) \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

# Install PHP Libs & Extensions
RUN apt update -y && apt install -y \
  libpng-dev \
  libpq-dev \
  libzip-dev \
  libicu-dev \
  libssl-dev \
  gnupg \
  && docker-php-ext-configure gd \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install pdo_pgsql \
  && docker-php-ext-install pdo \
  && docker-php-ext-install pgsql \
  && docker-php-ext-install exif \
  && docker-php-ext-install zip \
  && docker-php-ext-install opcache \
  && docker-php-ext-configure intl \
  && docker-php-ext-install intl \
  && docker-php-ext-install bcmath

RUN pecl install redis \
  && docker-php-ext-enable redis

# Setting up the user and group permissions and creating the necessary directories
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data
RUN mkdir -p /run/php/
RUN mkdir -p /var/log/php/
RUN mkdir -p /var/log/supervisor/
RUN touch /run/php/php-fpm.sock
RUN touch /run/php/php-fpm.pid
RUN touch /var/log/php/php-fpm.log
RUN touch /var/log/php/php-fpm-error.log
RUN touch /var/log/supervisor/laravel-queue.log
RUN chown www-data:www-data /run/php
RUN chown www-data:www-data /var/log/php
RUN chown www-data:www-data /var/log/php/php-fpm.log
RUN chown www-data:www-data /var/log/php/php-fpm-error.log

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

#NodeJS and NPM
RUN RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - &&\
  apt-get install -y nodejs

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt autoremove -y

# Copying configuration files to the container
RUN mkdir -p /run/nginx/
RUN touch /run/nginx/nginx.pid
RUN mkdir -p /etc/nginx/ssl/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN rm -rf /var/www/html
COPY ./.docker /tmp/docker
WORKDIR /var/www/

# Copy script file for initializing the container
COPY ./entrypoint.sh /bin/entrypoint.sh
RUN chmod 775 /bin/entrypoint.sh

EXPOSE 80 443 2222

ENTRYPOINT ["/bin/entrypoint.sh"]