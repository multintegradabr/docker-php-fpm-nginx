FROM php:7.4-fpm-alpine

ENV PATH ${PATH}:/home/site/wwwroot
ENV SSH_PASSWD "root:Docker!"

# Update packages and install bash
RUN apk update && apk upgrade
RUN apk add --no-cache --upgrade bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /home/site/wwwroot/" >> /etc/bash.bashrc

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
  htop

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
RUN touch /run/php/php-fpm.sock
RUN touch /run/php/php-fpm.pid

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install and configure Nginx
RUN apk add --no-cache nginx
RUN touch /run/nginx/nginx.pid
RUN mkdir /etc/nginx/ssl/
RUN mkdir /etc/nginx/conf.d/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# Copying configuration files to the container
COPY ./.docker /var/www/docker
WORKDIR /home/site/wwwroot/

# Copy script file for initializing the container
COPY ./init-container.sh /bin/init-container.sh
RUN chmod 775 /bin/init-container.sh

EXPOSE 80 443 2222

ENTRYPOINT ["/bin/init-container.sh"]
