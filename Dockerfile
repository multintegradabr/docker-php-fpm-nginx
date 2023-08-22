FROM php:8.2-fpm-alpine

ENV PATH ${PATH}:/var/www
ENV SSH_PASSWD "root:Docker!"

# Update packages and install bash
RUN apk update && apk upgrade
RUN apk add --no-cache --upgrade bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /var/www/" >> /etc/bash.bashrc

# Essential configuration and SSH installation
RUN echo "UTC-3" > /etc/timezone
RUN apk add openssh \
  && echo "$SSH_PASSWD" | chpasswd \
  && cd /etc/ssh/ \
  && ssh-keygen -A
COPY sshd_config /etc/ssh/

# Install essential Packages
RUN apk add --no-cache \
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
  github-cli \
  dialog \
  openrc \
  postgresql-client \
  htop \
  sudo 

# Install PHP Libs & Extensions
RUN apk add --no-cache \
  libpng-dev \
  libpq-dev \
  libzip-dev \
  icu-dev \
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
RUN apk --no-cache add pcre-dev ${PHPIZE_DEPS} \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && apk del pcre-dev ${PHPIZE_DEPS} \
  && rm -rf /tmp/pear

RUN mkdir -p /run/php/
RUN mkdir -p /var/log/php/
RUN mkdir -p /var/log/supervisor/
RUN touch /var/log/php/php-fpm.log
RUN touch /var/log/php/php-fpm-error.log
RUN chown www-data:www-data /run/php
RUN chown www-data:www-data /var/log/php
RUN chown www-data:www-data /var/log/php/php-fpm.log
RUN chown www-data:www-data /var/log/php/php-fpm-error.log

# Download Composer Files 
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install and configure Nginx
RUN apk add --no-cache nginx
RUN touch /run/nginx/nginx.pid
RUN mkdir /etc/nginx/ssl/
RUN mkdir /etc/nginx/conf.d/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN rm -rf /var/www/localhost/ 
RUN rm -rf /var/www/html/

#NodeJS and NPM
RUN apk add --no-cache nodejs npm

# Copying configuration files to the container
COPY ./.docker /tmp/docker
WORKDIR /var/www/

# Copy script file for initializing the container
COPY ./entrypoint.sh /bin/entrypoint.sh
RUN chmod 775 /bin/entrypoint.sh

EXPOSE 80 443 2222

ENTRYPOINT ["/bin/entrypoint.sh"]
