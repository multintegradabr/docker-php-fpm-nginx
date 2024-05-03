FROM ubuntu:24.04

# Set Environment Variables
ENV SSH_PASSWD "root:Docker!"
ENV NODE_MAJOR=18
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Fortaleza
ENV PHP_VERSION=8.2

# Install essential Packages
RUN apt update && apt install -y \
  sudo \
  supervisor \
  cron \
  curl \
  nano \
  wget \
  git \
  dialog \
  postgresql-client \
  htop

# Define the user multi
RUN usermod -l multi ubuntu
RUN usermod -d /home/multi -m multi
RUN groupmod -n multi ubuntu
RUN chown -R multi:multi /home/multi

RUN echo "multi:muti" | chpasswd
RUN echo "multi ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Configuration for SSH Server
RUN apt install -y --no-install-recommends openssh-server \
  && echo "$SSH_PASSWD" | chpasswd
COPY .docker/sshd_config /etc/ssh/

# Install PHP-FPM
RUN apt install -y software-properties-common
RUN add-apt-repository ppa:ondrej/php
RUN apt update && apt install -y \
  php${PHP_VERSION} \
  php${PHP_VERSION}-fpm \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-gmp \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-msgpack \
  php${PHP_VERSION}-igbinary \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-bcmath \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-memcache \
  php${PHP_VERSION}-swoole \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-exif 

#Install Memcached and php-memcached
RUN apt install -y memcached libmemcached-tools
RUN systemctl enable memcached

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install and configure Nginx
RUN apt install -y nginx
COPY .docker/nginx/dhparams.pem /etc/nginx/dhparams.pem
RUN mkdir -p /etc/nginx/ssl/
COPY .docker/nginx/nginx.conf /etc/nginx/nginx.conf

#NodeJS
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - &&\
  apt-get install -y nodejs

# Install Github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt autoremove -y  

# Copy the entrypoint script
COPY .docker/scripts/entrypoint.sh /bin/entrypoint.sh
RUN chmod 775 /bin/entrypoint.sh

USER multi:multi

# Create Logs folder and copy the configuration files
RUN mkdir -p /home/multi/LogFiles
COPY /.docker /usr/local/docker
RUN sudo chown multi:multi /usr/local/docker
WORKDIR /home/multi/app

EXPOSE 80 443 9000

ENTRYPOINT ["sudo", "-E", "/bin/entrypoint.sh"]