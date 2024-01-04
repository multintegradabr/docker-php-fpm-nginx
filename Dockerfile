FROM php:8.2-fpm

ENV PATH ${PATH}:/var/www
ENV SSH_PASSWD "root:Docker!"
ENV NODE_MAJOR=18

# Install sudo and create a new user multi
RUN apt update && apt install sudo
RUN groupadd -g 1000 multi && \
  useradd -u 1000 -g multi -m -d /home/multi -s /bin/bash multi && \
  PASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1) && \
echo "multi:$PASSWORD" | chpasswd
RUN chown -R multi:multi /home/multi
RUN echo "multi ALL=NOPASSWD: ALL" > /etc/sudoers.d/multi

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
  ca-certificates \
  cron

# Install Github CLI
RUN sudo apt update \
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
RUN mkdir -p /run/php/
RUN mkdir -p /var/log/php/
RUN touch /run/php/php-fpm.sock
RUN touch /run/php/php-fpm.pid
RUN touch /var/log/php/php-fpm.log
RUN touch /var/log/php/php-fpm-error.log
RUN touch /var/log/php/laravel-queue.log
RUN chown multi:multi /run/php
RUN chown multi:multi /var/log/php
RUN chown multi:multi /var/log/php/php-fpm.log
RUN chown multi:multi /var/log/php/php-fpm-error.log
RUN chown multi:multi /var/log/php/laravel-queue.log

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt autoremove -y

# Copying configuration files to the container
RUN mkdir -p /etc/nginx/ssl/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
COPY ./.docker /usr/local/docker
RUN chown multi:multi /usr/local/docker
RUN chown multi:multi /var/www
WORKDIR /var/www/

# Copy script file for initializing the container
COPY ./entrypoint.sh /bin/entrypoint.sh
RUN chmod 775 /bin/entrypoint.sh

EXPOSE 80 443 2222

USER multi:multi

ENTRYPOINT ["sudo", "-E", "/bin/entrypoint.sh"]
