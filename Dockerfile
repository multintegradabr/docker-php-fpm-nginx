FROM unit:php8.2

ENV PATH ${PATH}:/home/site/wwwroot
ENV SSH_PASSWD "root:Docker!"

# Atualizar os pacotes e instala o bash
RUN apt update -y && apt upgrade -y
RUN apt install bash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd
RUN echo "cd /home/site/wwwroot" >> /etc/bash.bashrc

# Configura o SSH para o Azure App Service
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
  wget \
  git \
  openssl \
  procps \
  postgresql-client \
  cron \
  supervisor \
  htop

# Instala extensões do PHP para o Laravel
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

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt update \
  && apt install gh -y

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

#NodeJS and NPM
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - &&\
  apt-get install -y nodejs

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt autoremove -y

# Copying configuration files to the container
COPY ./.docker /var/www/docker
WORKDIR /home/site/wwwroot/

# Copy script file for initializing the container
COPY ./init-container.sh /bin/init_container.sh
RUN chmod 775 /bin/init_container.sh

EXPOSE 80

ENTRYPOINT ["/bin/init_container.sh"]