#!/bin/bash
# Skamasle PHP SELECTOR for vesta
# version = beta 0.2.4.1
# From skamasle.com
# Run at your risk.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details. http://www.gnu.org/licenses/
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
echo "Cant get actual php versión"
echo "Run php -v and ask on forum or yo@skamasle.com"
echo "Leaving instalation..."
exit 4
fi

fixit () {
curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php${1}-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php${1}.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php${1}.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php${1}.tpl 

ln -s /etc/opt/remi/php55/php.ini /etc/php${1}.ini

ln -s  /etc/opt/remi/php55/php.d /etc/php${1}.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php${1}.sh
chmod 777 /opt/remi/php${1}/root/var/lib/php/session
tput setaf 1
echo "PHP ${2} Ready!"
tput sgr0
}
function phpinstall7 () {
ver=7.0
if [ $actual = $ver ];then
echo "Skip PHP 7.0 actually installed"
else
tput setaf 2
echo "Installing PHP 7.0"
yum install -y php70-php-imap php70-php-process php70-php-pspell php70-php-xml php70-php-xmlrpc php70-php-pdo php70-php-ldap php70-php-pecl-zip php70-php-common php70-php php70-php-mcrypt php70-php-gmp php70-php-mysqlnd php70-php-mbstring php70-php-gd php70-php-tidy php70-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

fixit 70
fi
}
function phpinstall71 () {
ver=7.1
if [ $actual = $ver ];then
echo "Skip PHP 7.1 actually installed"
else
tput setaf 2
echo "Installing PHP 7.1"
yum install -y php71-php-imap php71-php-process php71-php-pspell php71-php-xml php71-php-xmlrpc php71-php-pdo php71-php-ldap php71-php-pecl-zip php701-php-common php71-php php71-php-mcrypt php71-php-gmp php71-php-mysqlnd php71-php-mbstring php71-php-gd php71-php-tidy php71-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

fixit 71
fi
}

function phpinstall72 () {
ver=7.2
if [ $actual = $ver ];then
echo "Skip PHP 7.2 actually installed"
else
tput setaf 2
echo "Installing PHP 7.2"
yum install -y php72-php-imap php72-php-process php72-php-pspell php72-php-xml php72-php-xmlrpc php72-php-pdo php72-php-ldap php72-php-pecl-zip php701-php-common php72-php php72-php-mcrypt php72-php-gmp php72-php-mysqlnd php72-php-mbstring php72-php-gd php72-php-tidy php72-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

fixit 72
fi
}

function phpinstall56 () {
ver=5.6
if [ $actual = $ver ];then
echo "Skip php 5.6 actually installed"
else
tput setaf 2
echo "Instaling PHP 5.6"
yum install -y php56-php-imap php56-php-process php56-php-pspell php56-php-xml php56-php-xmlrpc php56-php-pdo php56-php-ldap php56-php-pecl-zip php56-php-common php56-php php56-php-mcrypt php56-php-mysqlnd php56-php-gmp php56-php-mbstring php56-php-gd php56-php-tidy php56-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

fixit 56
fi
}
function phpinstall55 () {
ver=5.5
if [ $actual = $ver ];then
echo "Skip php 5.5 actually installed"
else
tput setaf 2
echo "Instaling PHP 5.5"
yum install -y php55-php-imap php55-php-process php55-php-pspell php55-php-xml php55-php-xmlrpc php55-php-pdo php55-php-ldap php55-php-pecl-zip php55-php-common php55-php php55-php-mcrypt php55-php-mysqlnd php55-php-gmp php55-php-mbstring php55-php-gd php55-php-tidy php55-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

fixit 55
fi
}
function phpinstall54 () {
ver=5.4
if [ $actual = $ver ];then
echo "Skip php 5.4 actually installed"
else
tput setaf 2
echo "Instaling PHP 5.4"
yum install -y  php54-php-pspell php54-php-process php54-php-imap php54-php-xml php54-php-xmlrpc php54-php-pdo php54-php-ldap php54-php-pecl-zip php54-php-common php54-php-gmp php54-php php54-php-mcrypt php54-php-mysqlnd php54-php-mbstring php54-php-gd php54-php-tidy php54-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "........"

fixit 54
fi
}

if [ -e /etc/redhat-release ];then
	if [[ "$sistema" -eq 7  ||  "$sistema" -eq 6 ]]; then
tput setaf 4
echo "You have remi repo installed and run: "
cat /etc/redhat-release
echo "##########"
echo "Start installing aditional php version"
echo "##########"
tput setaf 2
echo "Actually you runing php $actual, so I will skip it"
tput sgr0
	phpinstall54
	phpinstall55
	phpinstall56
	phpinstall7
	phpinstall71
	phpinstall72
echo "################################"
echo "Aditional PHP versión installed!"
echo "More info on skamasle.com or vestacp forums."
fi
else
	echo "Only support centos"
exit 3
fi
