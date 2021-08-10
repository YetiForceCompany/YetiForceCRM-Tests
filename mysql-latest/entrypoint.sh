#! /bin/bash
set -e
echo " -----  Start -----"

#https://github.com/actions/cache/blob/main/examples.md#php---composer

cd /var/www/html/

echo " -----  Copy files  -----"
cp -R $GITHUB_WORKSPACE/* /var/www/html

#cp /var/www/html/tests/setup/db/mysql.cnf /etc/mysql/mysql.conf.d/50-server.cnf
cp /var/www/html/tests/setup/db/mysql_mysql8.cnf /etc/mysql/conf.d/50-server.cnf
cp /var/www/html/tests/setup/nginx/docker.conf /etc/nginx/sites-available/default
cp /var/www/html/tests/setup/nginx/yetiforce.conf /etc/nginx/yetiforce.conf
cp /var/www/html/tests/setup/fpm/www.conf /etc/php/$PHP_VER/fpm/pool.d/www.conf
if [ "$INSTALL_MODE" != "PROD" ]; then
    cp /var/www/html/tests/setup/php/dev.ini /etc/php/$PHP_VER/mods-available/yetiforce.ini
else
    cp /var/www/html/tests/setup/php/prod.ini /etc/php/$PHP_VER/mods-available/yetiforce.ini
fi

ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/cli/conf.d/30-yetiforce.ini
ln -s /etc/php/$PHP_VER/mods-available/yetiforce.ini /etc/php/$PHP_VER/fpm/conf.d/30-yetiforce.ini

echo " -----  chmod  -----"
chmod -R +x /var/www/html/tests/setup

echo " -----  tests/setup/dependency.sh  -----"
/var/www/html/tests/setup/dependency.sh

echo " -----  tests/setup/docker_post_install.php  -----"
php /var/www/html/tests/setup/docker_post_install.php

echo " -----  service --status-all  -----"
service --status-all
echo " -----  systemctl --type=service  -----"
systemctl --type=service
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
