#! /bin/bash
set -e
echo " -----  Start -----"

#https://github.com/actions/cache/blob/main/examples.md#php---composer

cd /var/www/html/

echo " -----  Copy files  -----"
cp -R $GITHUB_WORKSPACE/* /var/www/html

cp /var/www/html/tests/setup/db/mysql.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
cp /var/www/html/tests/setup/nginx/docker.conf /etc/nginx/sites-available/default
cp /var/www/html/tests/setup/nginx/yetiforce.conf /etc/nginx/yetiforce.conf
cp /var/www/html/tests/setup/fpm/docker.conf /etc/php/$PHP_VER/fpm/pool.d/www.conf
if [ "$INSTALL_MODE" != "PROD" ]; then
    cp /var/www/html/tests/setup/php/dev.ini /etc/php/$PHP_VER/mods-available/yetiforce.ini
else
    cp /var/www/html/tests/setup/php/prod.ini /etc/php/$PHP_VER/mods-available/yetiforce.ini
fi
echo 'opcache.jit = "tracing"' >> /etc/php/$PHP_VER/mods-available/yetiforce.ini
echo 'opcache.jit_buffer_size = 150M' >> /etc/php/$PHP_VER/mods-available/yetiforce.ini

ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/cli/conf.d/30-yetiforce.ini
ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/fpm/conf.d/30-yetiforce.ini


sed -i "s/auto_detect_line_endings/;auto_detect_line_endings/g" /etc/php/$PHP_VER/cli/conf.d/30-yetiforce.ini
sed -i "s/auto_detect_line_endings/;auto_detect_line_endings/g" /etc/php/$PHP_VER/fpm/conf.d/30-yetiforce.ini

echo " -----  chmod  -----"
chmod -R +x /var/www/html/tests/setup


echo " -----  tests/setup/dependency.sh  -----"
rm -rf composer.lock
rm -rf composer_dev.lock
/var/www/html/tests/setup/dependency.sh

echo " -----  tests/setup/docker_post_install.php  -----"
php /var/www/html/tests/setup/docker_post_install.php

echo " -----  service mariadb start  -----"
service mariadb start;
service mariadb status
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
echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';" | mysql --user=root;
echo "DELETE FROM mysql.user WHERE User='';" | mysql --user=root;
echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql --user=root;
echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';" | mysql --user=root;
echo "CREATE DATABASE yetiforce;" | mysql --user=root;
echo "CREATE USER 'yetiforce'@'localhost' IDENTIFIED BY '$DB_USER_PASS';" | mysql --user=root;
echo "GRANT ALL PRIVILEGES ON yetiforce.* TO 'yetiforce'@'localhost';" | mysql --user=root;
echo "FLUSH PRIVILEGES;" | mysql --user=root

chmod -R +r /var/log/
cd /var/www/html/tests

/var/www/html/vendor/bin/phpunit --verbose --colors=always --testsuite NoGUI

echo " ----- Tests CLI    -----"
php /var/www/html/cli.php -m System -a history
php /var/www/html/cli.php -m System -a reloadModule
php /var/www/html/cli.php -m System -a showProducts
php /var/www/html/cli.php -m System -a reloadUserPrivileges

php /var/www/html/cli.php -m Cleaner -a session
php /var/www/html/cli.php -m Cleaner -a cacheData

php /var/www/html/cli.php -m Users -a resetAllPasswords -l demo -p Tests9876 -c
php /var/www/html/cli.php -m Users -a resetAllPasswords -c
