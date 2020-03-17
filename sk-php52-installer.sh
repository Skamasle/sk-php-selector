#!/bin/bash
# Vesta PHP 5.2 compiler.
# 29 febero 2016
# Maks Skamasle -> skamasle.com  | Twitter @skamasle

OS=$(cat /etc/redhat-release |cut -d" " -f3|cut -d "." -f1)
if [ $OS = "6" ]; then

yum -y --enablerepo=remi install gcc make gcc-c++ cpp libxml2-devel openssl-devel bzip2-devel libjpeg-devel libpng-devel freetype-devel openldap-devel postgresql-devel aspell-devel net-snmp-devel libxslt-devel libc-client-devel libicu-devel gmp-devel curl-devel libmcrypt-devel unixODBC-devel pcre-devel sqlite-devel db4-devel enchant-devel libXpm-devel mysql-devel readline-devel libedit-devel recode-devel libtidy-devel
else
	echo "This script run only in centos 6 and you have"
	cat /etc/redhat-release
	exit 1
fi	

cd /usr/local/src

wget http://mirror.skamasle.com/vestacp/PHP/bin/php-5.2.17.tar.gz

tar xzf php-5.2.17.tar.gz
cd php-5.2.17/

./configure --with-libdir=lib64 --cache-file=./config.cache --prefix=/usr/local/php-5.2.17 --with-config-file-path=/usr/local/php-5.2.17/etc --disable-debug --with-pic --disable-rpath  --with-bz2 --with-curl --with-freetype-dir=/usr/local/php-5.2.17 --with-png-dir=/usr/local/php-5.2.17 --enable-gd-native-ttf --without-gdbm --with-gettext --with-gmp --with-iconv --with-jpeg-dir=/usr/local/php-5.2.17 --with-openssl --with-pspell --with-pcre-regex --with-zlib --enable-exif --enable-ftp --enable-sockets --enable-sysvsem --enable-sysvshm --enable-sysvmsg --enable-wddx --with-kerberos --with-unixODBC=/usr --enable-shmop --enable-calendar --with-libxml-dir=/usr/local/php-5.2.17 --enable-pcntl --with-imap --with-imap-ssl --enable-mbstring --enable-mbregex --with-gd --enable-bcmath --with-xmlrpc --with-ldap --with-ldap-sasl --with-mysql=/usr --with-mysqli --with-snmp --enable-soap --with-xsl --enable-xmlreader --enable-xmlwriter --enable-pdo --with-pdo-mysql --with-pdo-pgsql --with-pear=/usr/local/php-5.2.17/pear --with-mcrypt --without-pdo-sqlite --with-config-file-scan-dir=/usr/local/php-5.2.17/php.d --enable-fastcgi

status=$?

if [ $status = 0 ];then
	make

	make install


	cp /usr/local/src/php-5.2.17/php.ini-recommended /usr/local/php-5.2.17/etc/php.ini

	curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php52.sh > /usr/local/vesta/data/templates/web/httpd/sk-php52.sh

	ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php52.stpl

	ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php52.tpl 
	chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php52.sh

	echo "PHP 5.2 compiled and templates installed"

else
	echo "Stop compile, we get some errors"
fi
