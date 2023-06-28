FROM php:8.2-fpm

ENV PATH ${PATH}:/var/www
ENV SSH_PASSWD "root:Docker!"

# Update packages and install bash
RUN apt update -y && apt upgrade -y
RUN apt install bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /var/www" >> /etc/bash.bashrc

# Essential configuration and SSH installation
RUN echo "UTC-3" > /etc/timezone
RUN apt update \
  && apt install -y --no-install-recommends dialog \
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
  nano \
  sudo \
  wget \
  supervisor \
  git \
  openssl \
  bash \
  dialog \
  postgresql-client \
  htop \
  cron

# Install Github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 
RUN chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null 
RUN apt update && apt install gh -y

# Install PHP Libs & Extensions
RUN apt update -y && apt install -y \
  libpng-dev \
  libpq-dev \
  libzip-dev \
  libicu-dev \
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

RUN mkdir -p /run/php/
RUN touch /run/php/php-fpm.sock
RUN touch /run/php/php-fpm.pid

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install and configure Nginx
RUN echo "deb http://nginx.org/packages/mainline/debian/ bullseye nginx" > /etc/apt/sources.list.d/nginx.list
RUN wget http://nginx.org/keys/nginx_signing.key
RUN apt-key add nginx_signing.key
RUN apt update -y && apt install nginx -y

RUN mkdir -p /run/nginx/
RUN touch /run/nginx/nginx.pid
RUN mkdir -p /etc/nginx/ssl/
RUN mkdir -p /etc/nginx/conf.d/
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN rm -rf /var/www/localhost/ 
RUN rm -rf /var/www/html/

#NodeJS and NPM
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - &&\
  apt-get install -y nodejs

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt autoremove -y

# Copying configuration files to the container
COPY ./.docker /tmp/docker
WORKDIR /var/www/

# Copy script file for initializing the container
COPY ./entrypoint.sh /bin/entrypoint.sh
RUN chmod 775 /bin/entrypoint.sh

EXPOSE 80 443 2222

ENTRYPOINT ["/bin/entrypoint.sh"]