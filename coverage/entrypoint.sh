#! /bin/bash
#set -e
echo " -----  free -m  -----"
free -m 
echo " -----  Start -----"

if [ "$COVERAGE" == "true" ]; then
	echo " -----  install pcov -----"
	ln -s /etc/php/cover.ini /etc/php/$PHP_VER/cli/conf.d/40-yetiforce-cover.ini
	ln -s /etc/php/cover.ini /etc/php/$PHP_VER/fpm/conf.d/40-yetiforce-cover.ini
fi

#https://github.com/actions/cache/blob/main/examples.md#php---composer

cd /var/www/html/

echo " -----  Copy files  -----"
cp -R $GITHUB_WORKSPACE/* /var/www/html
cp -R $GITHUB_WORKSPACE/.scrutinizer.yml /var/www/html/.scrutinizer.yml

cp /var/www/html/tests/setup/db/mysql.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
cp /var/www/html/tests/setup/nginx/www.conf /etc/nginx/sites-available/default
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
rm /var/www/html/tests/setup/docker_post_install.php

echo " -----  /var/www/html/tests/setup/selenium.sh -----"
chmod 777 /var/www/html/tests/setup/selenium.sh
/var/www/html/tests/setup/selenium.sh

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

echo " ----- /var/www/html/vendor/bin/phpunit --verbose --colors=always --testsuite All    -----"
/var/www/html/vendor/bin/phpunit --verbose --colors=always --log-junit '/var/www/html/tests/coverages/execution.xml' --testsuite All


if [ "$COVERAGE" == "true" ]; then
	echo " -----  after test -----"
	php /var/www/html/tests/setup/codeCoverageReport.php

	echo " ----- /var/www/html/tests/coverages/  -----"
	ls -all /var/www/html/tests/coverages/
	mkdir $GITHUB_WORKSPACE/tests/coverages/
	
	echo " ----- cp -R /var/www/html/tests/coverages/* $GITHUB_WORKSPACE/tests/coverages/  -----"
	cp -R /var/www/html/* $GITHUB_WORKSPACE
	
	ls -all /var/www/html/

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
echo " ----- LS /var/log/mysql  -----"
ls -all /var/log/mysql
