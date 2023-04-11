FROM php:7.4-fpm

ENV PATH ${PATH}:/home/site/wwwroot
ENV SSH_PASSWD "root:Docker!"

# Update packages and install bash
RUN apt update -y && apt upgrade -y
RUN apt install bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /home/site/wwwroot/" >> /etc/bash.bashrc

# Essential configuration and SSH installation
RUN echo "UTC-3" > /etc/timezone
RUN apt-get update \
  && apt-get install -y --no-install-recommends dialog \
  && apt-get update \
  && apt-get install -y --no-install-recommends openssh-server \
  && echo "$SSH_PASSWD" | chpasswd

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
  bash \
  dialog \
  openrc \
  postgresql-client \
  htop \
  cron

# Install PHP Libs & Extensions
RUN apt install -y \
  libpng-dev \
  libpq-dev \
  libzip-dev \
  libicu-dev \
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

RUN mkdir -p /run/php/
RUN touch /run/php/php-fpm.sock
RUN touch /run/php/php-fpm.pid

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install and configure Nginx
RUN apt install -y nginx
RUN mkdir -p /run/nginx/
RUN touch /run/nginx/nginx.pid
RUN mkdir /etc/nginx/ssl/
RUN mkdir -p /etc/nginx/conf.d/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

#NodeJS and NPM
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - &&\
  apt-get install -y nodejs

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN apt autoremove -y

# Copying configuration files to the container
COPY ./.docker /var/www/docker
WORKDIR /home/site/wwwroot/

# Copy script file for initializing the container
COPY ./init-container.sh /bin/init_container.sh
RUN chmod 775 /bin/init_container.sh

EXPOSE 80 443 2222

#Installing DataDog Agent
RUN DD_API_KEY=4190390b821cd76e0f809161f3386d3a DD_SITE="datadoghq.com" DD_INSTALL_ONLY="true" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"

#"Downloading DataDog Setup Script"
RUN curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php

#"Installing DataDog Setup Script"
RUN php datadog-setup.php --php-bin=all --enable-appsec --enable-profiling

ENTRYPOINT ["/bin/init_container.sh"]