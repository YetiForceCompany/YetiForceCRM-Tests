#! /bin/bash
set -e
echo " -----  free -m  -----"
free -m
echo " -----  lscpu  -----"
lscpu
echo " -----  Start -----"

if [ "$COVERAGE" == "true" ]; then
	echo " -----  copy 40-yetiforce-cover.ini -----"
	ln -s /etc/php/cover.ini /etc/php/$PHP_VER/cli/conf.d/40-yetiforce-cover.ini
	ln -s /etc/php/cover.ini /etc/php/$PHP_VER/fpm/conf.d/40-yetiforce-cover.ini
fi

#https://github.com/actions/cache/blob/main/examples.md#php---composer

cd /var/www/html/

echo " -----  Copy files  -----"
cp -R $GITHUB_WORKSPACE/* /var/www/html
cp -R $GITHUB_WORKSPACE/.scrutinizer.yml /var/www/html/.scrutinizer.yml

cp /var/www/html/tests/setup/db/mysql.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
cp /var/www/html/tests/setup/nginx/tests.conf /etc/nginx/sites-available/default
cp /var/www/html/tests/setup/nginx/yetiforce.conf /etc/nginx/yetiforce.conf
cp /var/www/html/tests/setup/fpm/tests.conf /etc/php/$PHP_VER/fpm/pool.d/www.conf
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
rm /var/www/html/tests/setup/docker_post_install.php


#echo " -----  cat /etc/php/$PHP_VER/fpm/php-fpm.conf  -----"
#cat /etc/php/$PHP_VER/fpm/php-fpm.conf
#echo " -----  cat /etc/php/$PHP_VER/fpm/pool.d/www.conf  -----"
#cat /etc/php/$PHP_VER/fpm/pool.d/www.conf

echo " -----  npm install -g n   -----"
curl -fsSL https://deb.nodesource.com/setup_current.x | bash -
apt-get install -y nodejs
echo " -----  cypress install   -----"
cd /var/www/html/tests/Gui
yarn install

echo " -----  service mysql start  -----"
service mysql start;
service mysql status

echo " -----  service cron start  -----"
service cron start

echo " -----  PHP-FPM  -----"
service php$PHP_VER-fpm start
#/etc/init.d/php$PHP_VER-fpm start
service php$PHP_VER-fpm status
service php$PHP_VER-fpm restart

php -v

echo " -----  nginx  -----"
service nginx start
service nginx status
service nginx reload

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

echo " ----- phpunit Init    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution1.xml' --testsuite Init

export YETI_INSTALLED=1

echo " ----- phpunit Base    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution2.xml' --testsuite Base

echo " ----- phpunit Integrations    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution3.xml' --testsuite Integrations

echo " ----- phpunit Settings    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution4.xml' --testsuite Settings

echo " ----- phpunit App    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution5.xml' --testsuite App

echo " ----- cypress run    -----"
ELECTRON_EXTRA_LAUNCH_ARGS=--disable-gpu
cd /var/www/html/tests/Gui
./node_modules/.bin/cypress run
cd /var/www/html/tests

export SHOW_LOGS=1

echo " ----- Tests CLI    -----"
php /var/www/html/cli.php -m System -a history
php /var/www/html/cli.php -m System -a reloadModule
php /var/www/html/cli.php -m System -a showProducts
php /var/www/html/cli.php -m System -a reloadUserPrivileges

php /var/www/html/cli.php -m Cleaner -a session
php /var/www/html/cli.php -m Cleaner -a cacheData

php /var/www/html/cli.php -m Users -a resetAllPasswords -l demo -p Tests9876 -c
php /var/www/html/cli.php -m Users -a resetAllPasswords -c

php /var/www/html/cli.php -m Environment -a confReportErrors >> /var/www/html/cache/logs/cli_Environment_confReportErrors.log
php /var/www/html/cli.php -m Environment -a confReportAll  >> /var/www/html/cache/logs/cli_Environment_confReportAll.log

if [ "$COVERAGE" == "true" ]; then
	echo " -----  after test -----"
	php /var/www/html/tests/setup/codeCoverageReport.php

	echo " ----- /var/www/html/tests/coverages/  -----"
	mkdir $GITHUB_WORKSPACE/tests/coverages/

	echo " ----- cp -R /var/www/html/tests/coverages/* $GITHUB_WORKSPACE/tests/coverages/  -----"
	cp -R /var/www/html/* $GITHUB_WORKSPACE

	echo " ----- bash <(curl -s https://codecov.io/bash) -f tests/coverages/coverage.xml  -----"
	cd /var/www/html
	bash <(curl -s https://codecov.io/bash) -f tests/coverages/coverage.xml

	echo " ----- bash <(curl -Ls https://coverage.codacy.com/get.sh) report -r /var/www/html/tests/coverages/coverage4.xml  -----"
	bash <(curl -Ls https://coverage.codacy.com/get.sh) report -r /var/www/html/tests/coverages/coverage4.xml
fi

echo " ----- LS  /var/www/html/cache/logs  -----"
ls -all  /var/www/html/cache/logs
echo " ----- LS /var/log/  -----"
ls -all /var/log/
echo " ----- LS /var/log/nginx  -----"
ls -all /var/log/nginx
#echo " ----- LS /var/log/mysql  -----"
#ls -all /var/log/mysql

#echo " ----- cat /var/log/fpm-php.www.log  -----"
#cat /var/log/fpm-php.www.log
#echo " ----- cat /var/log/php_error.log  -----"
#cat /var/log/php_error.log
#echo " ----- cat /var/log/nginx/localhost_access.log  -----"
# cat /var/log/nginx/localhost_access.log
#echo " ----- cat /var/log/nginx/localhost_error.log  -----"
#cat /var/log/nginx/localhost_error.log
#echo " ----- cat /var/log/nginx/error.log  -----"
#cat /var/log/nginx/error.log
