#!/bin/bash
# Skamasle PHP SELECTOR for vesta
# version = beta 0.5 Code simplified just for testing
# From skamasle.com
# Run at your risk.
sistema=$(grep -o "[0-9]" /etc/redhat-release |head -n1)
sklog=/var/log/skphp.log
if [ ! -e /etc/yum.repos.d/remi.repo ]; then
echo "I not found remi repo, stop install... "
exit 2
fi
# fix php 7 version detection...
vp=$(php -v |head -n1 |cut -c5)
if [ "$vp" -eq 5 ];then
	actual=$(php -v| head -n1 | grep --only-matching --perl-regexp "5\.\\d+")
elif [ "$vp" -eq 7 ];then
	actual=$(php -v| head -n1 | grep --only-matching --perl-regexp "7\.\\d+")
else
echo "Cant get actual php version"
echo "Run php -v and ask on forum or yo@skamasle.com"
echo "Leaving instalation..."
exit 4
fi

fixit () {
curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php${1}-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php${1}.sh
ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php${1}.stpl
ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php${1}.tpl 
if [ -e /etc/opt/remi/php${1}/php.ini ]; then
    ln -s /etc/opt/remi/php${1}/php.ini /etc/php${1}.ini
    ln -s  /etc/opt/remi/php${1}/php.d /etc/php${1}.d
elif [ -e /opt/remi/php${1}/root/etc/php.ini ]; then
        ln -s /etc/opt/remi/php${1}/php.ini /etc/php${1}.ini
        ln -s  /etc/opt/remi/php${1}/php.d /etc/php${1}.d
fi
chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php${1}.sh

tput setaf 1
echo "PHP ${ver2} Ready!"
tput sgr0
}

installit() {
ver=$1
ver2=$2

if [ $actual = $ver2 ];then
    echo "Skip php $ver2 actually installed"
else
tput setaf 2
echo "Instaling PHP $ver2"
yum install -y  php${ver}-php-pspell php${ver}-php-process php${ver}-php-imap php${ver}-php-xml php${ver}-php-xmlrpc php${ver}-php-pdo php${ver}-php-ldap php${ver}-php-pecl-zip php${ver}-php-common php${ver}-php-gmp php${ver}-php php${ver}-php-mysqlnd php${ver}-php-mbstring php${ver}-php-gd php${ver}-php-tidy php${ver}-php-pecl-memcache --enablerepo=remi >> $sklog
echo "........"
fixit $ver $ver2
fi
}
all () {
tput setaf 4
echo "You Select install all php versions"
tput sgr0
    installit 54 5.4
    installit 55 5.5
    installit 56 5.6
    installit 70 7.0
    installit 71 7.1
    installit 72 7.2
    installit 73 7.3
    installit 74 7.4
}
usage () {
tput setaf 1
	echo "You can select php version you need, run your script as :"
tput sgr0
echo "bash $0 php55"
echo "or"
echo "bash $0 php56 php55 php71"
tput setaf 1
	echo "or install all available versions :"
tput sgr0
echo "bash $0 all"
tput setaf 1
    echo "###############################################"
	echo "Supported Versions: 54, 55, 56, 70, 71, 72, 73"
    echo "###############################################"
tput sgr0
}

if [ -e /etc/redhat-release ];then
	if [ -z "$1" ]; then
		usage
		exit 2
	fi
	if [[ "$sistema" -eq 7  ||  "$sistema" -eq 6 ]]; then
		tput setaf 4
			echo "You have remi repo installed and run: "
			cat /etc/redhat-release
			echo "##########"
			echo "Start installing aditional php version"
			echo "##########"
		tput sgr0
for args in "$@" ; do
tput setaf 2
	echo "Actually you runing php $actual, so I will skip it"
tput sgr0
		case $args  in
			php54) installit 54 5.4 ;;
			php55) installit 55 5.5 ;;
			php56) installit 56 5.6 ;;
			php70) installit 70 7.0 ;;
			php71) installit 71 7.1 ;;
			php72) installit 72 7.2 ;;
            php73) installit 73 7.3 ;;
            php74) installit 74 7.4 ;;
			all) all ;;
	  esac
done
echo "################################"
echo "Aditional PHP versión installed!"
echo "More info on skamasle.com or forum.vestacp.com or follow me in twiter @skamasle"
echo "################################"
		fi
else
	echo "Only support centos"
exit 3
fi
