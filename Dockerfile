FROM php:8.2-fpm-alpine

ENV PATH ${PATH}:/home/site/wwwroot
ENV SSH_PASSWD "root:Docker!"

# Update packages and install bash
RUN apk update && apk upgrade
RUN apk add --no-cache --upgrade bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd

# Essential configuration
RUN echo "UTC-3" > /etc/timezone
RUN echo "$SSH_PASSWD" | chpasswd

# Install essential Packages
RUN apk add --no-cache \
  nginx \
  zip \
  grep \
  unzip \
  curl \
  supervisor \
  nano \
  wget \
  git \
  openssh-server \
  openssl \
  bash \
  github-cli \
  dialog \
  openrc \
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

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Creating folders for the project
RUN mkdir -p /home/LogFiles/
RUN mkdir -p /home/site/wwwroot/
RUN mkdir -p /home/site/docker/
RUN mkdir /etc/nginx/ssl/
RUN mkdir /etc/nginx/conf.d/
RUN mkdir -p /etc/supervisor/conf.d/
RUN mkdir -p /run/php/

# Copying configuration files to the container
# COPY 	/usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
COPY ./.docker /home/site/docker
COPY sshd_config /etc/ssh/
RUN touch /run/php/php-fpm.sock

# Copy script file for initializing the container
COPY ./init-container.sh /bin/init-container.sh
RUN chmod 775 /bin/init-container.sh

WORKDIR /home/site/wwwroot/

EXPOSE 80 443

ENTRYPOINT ["/bin/init-container.sh"]