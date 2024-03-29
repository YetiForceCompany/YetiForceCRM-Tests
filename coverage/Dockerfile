FROM debian:buster

MAINTAINER m.krzaczkowski@yetiforce.com

ARG DEBIAN_FRONTEND=noninteractive

#INSTALL_MODE = PROD , DEV , TEST
ENV INSTALL_MODE TEST
ENV PHP_VER 7.4
ENV GUI_MODE true
ENV COVERAGE true

ENV DB_USER_NAME yetiforce
ENV DB_USER_PASS Q4WK2yRUpliyjMRivDJE
ENV DB_PORT 3306
ARG DB_ROOT_PASS=1r2VdePVnNxluabdGuqh


ENV PROVIDER tests

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils curl openssl wget ca-certificates apt-transport-https lsb-release gnupg

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update
RUN apt-get install -y --no-install-recommends mariadb-server mariadb-client
RUN apt-get install -y --no-install-recommends nginx nginx-extras "php${PHP_VER}"-fpm "php${PHP_VER}"-mysql "php${PHP_VER}"-curl "php${PHP_VER}"-intl "php${PHP_VER}"-gd "php${PHP_VER}"-fpm "php${PHP_VER}"-bcmath "php${PHP_VER}"-soap "php${PHP_VER}"-ldap "php${PHP_VER}"-imap "php${PHP_VER}"-xml "php${PHP_VER}"-cli "php${PHP_VER}"-zip "php${PHP_VER}"-json "php${PHP_VER}"-mbstring "php${PHP_VER}"-imagick "php${PHP_VER}"-apcu zip unzip cron

RUN apt-get install -y --no-install-recommends nodejs npm yarn "php${PHP_VER}"-pcov git
RUN apt-get -y autoclean

# RUN apt-cache search php
# RUN dpkg --get-selections | grep php

RUN rm /var/www/html/index.nginx-debian.html
RUN echo "PROVIDER=tests" > /etc/environment

RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

RUN composer --version

COPY entrypoint.sh /entrypoint.sh
COPY cover.ini /etc/php/cover.ini
RUN chmod 777 /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT [ "/entrypoint.sh" ]
