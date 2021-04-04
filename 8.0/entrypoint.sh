#!/bin/bash
echo " -----  Start -----"
printenv

#https://github.com/actions/cache/blob/main/examples.md#php---composer

cd /var/www/html/

echo " -----  Copy files  -----"
cp -R $GITHUB_WORKSPACE/* /var/www/html

cp /var/www/html/tests/setup/crons.conf /etc/cron.d/yetiforcecrm
cp /var/www/html/tests/setup/db/mysql.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
cp /var/www/html/tests/setup/nginx/www.conf /etc/nginx/sites-available/default
cp /var/www/html/tests/setup/nginx/yetiforce.conf /etc/nginx/yetiforce.conf
cp /var/www/html/tests/setup/fpm/www.conf /etc/php/$PHP_VER/fpm/pool.d/www.conf
cp /var/www/html/tests/setup/php/prod.ini /etc/php/$PHP_VER/mods-available/yetiforce.ini

ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/cli/conf.d/30-yetiforce.ini
ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/fpm/conf.d/30-yetiforce.ini

crontab /etc/cron.d/yetiforcecrm

echo " -----  chmod  -----"
chmod -R +x /var/www/html/tests/setup

echo " -----  tests/setup/dependency.sh  -----"
/var/www/html/tests/setup/dependency.sh

echo " -----  tests/setup/docker_post_install.php  -----"
php /var/www/html/tests/setup/docker_post_install.php

echo " -----  service mysql start  -----"
service mysql start;
service mysql status
echo " -----  service cron start  -----"
service cron start
echo " -----  nginx  -----"
service nginx start
service nginx status
echo " -----  PHP-FPM  -----"
/etc/init.d/php$PHP_VER-fpm start
service php$PHP_VER-fpm status

echo " -----  chown  -----"
chown -R www-data:www-data /var/www/

echo " -----  mysql  -----"
mysql -uroot mysql;
mysqladmin password "$DB_ROOT_PASS";
echo "UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';" | mysql --user=root;
echo "DELETE FROM mysql.user WHERE User='';" | mysql --user=root;
echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql --user=root;
echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';" | mysql --user=root;
echo "CREATE DATABASE yetiforce;" | mysql --user=root;
echo "CREATE USER 'yetiforce'@'localhost' IDENTIFIED BY '$DB_USER_PASS';" | mysql --user=root;
echo "GRANT ALL PRIVILEGES ON yetiforce.* TO 'yetiforce'@'localhost';" | mysql --user=root;
echo "FLUSH PRIVILEGES;" | mysql --user=root


cd /var/www/html/tests
/var/www/html/vendor/bin/phpunit --verbose --colors=always --testsuite Init,Settings,Base,Integrations,Apps


echo " -----  Logs: /var/log/fpm-php.www.log   -----"
cat /var/log/fpm-php.www.log
echo " -----  Logs: /var/log/php_error.log   -----"
cat /var/log/php_error.log
echo " -----  Logs: /var/log/mysql/error.log   -----"
cat /var/log/mysql/error.log
echo " -----  Logs: /var/www/html/cache/logs/system.log   -----"
cat /var/www/html/cache/logs/system.log

echo " ----- LS  /var/www/html/cache/logs  -----"
ls -all  /var/www/html/cache/logs
echo " ----- LS /var/log/  -----"
ls -all /var/log/
