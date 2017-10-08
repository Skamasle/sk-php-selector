#!/bin/bash
# Skamasle PHP SELECTOR for vesta
# version = beta 0.2.4
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

function phpinstall7 () {
ver=7.0
if [ $actual = $ver ];then
echo "Skip PHP 7.0 actually installed"
else
tput setaf 2
echo "Installing PHP 7.0"
yum install -y php70-php-imap php70-php-process php70-php-pspell php70-php-xml php70-php-xmlrpc php70-php-pdo php70-php-ldap php70-php-pecl-zip php70-php-common php70-php php70-php-mcrypt php70-php-gmp php70-php-mysqlnd php70-php-mbstring php70-php-gd php70-php-tidy php70-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php70-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php70.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php70.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php70.tpl  

ln -s /etc/opt/remi/php70/php.ini /etc/php70.ini

ln -s  /etc/opt/remi/php70/php.d /etc/php70.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php70.sh
tput setaf 1
echo "PHP 7.0 Ready!"
tput sgr0 
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

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php71-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php71.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php71.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php71.tpl  

ln -s /etc/opt/remi/php71/php.ini /etc/php71.ini

ln -s  /etc/opt/remi/php71/php.d /etc/php71.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php71.sh
tput setaf 1
echo "PHP 7.1 Ready!"
tput sgr0 
fi
}

function phpinstall72 () {
ver=7.2
if [ $actual = $ver ];then
echo "Skip PHP 7.2 actually installed"
else
tput setaf 2
echo "Installing PHP 7.1"
yum install -y php72-php-imap php72-php-process php72-php-pspell php72-php-xml php72-php-xmlrpc php72-php-pdo php72-php-ldap php72-php-pecl-zip php701-php-common php72-php php72-php-mcrypt php72-php-gmp php72-php-mysqlnd php72-php-mbstring php72-php-gd php72-php-tidy php72-php-pecl-memcache --enablerepo=remi  >> $sklog
echo "......."

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php72-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php72.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php72.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php72.tpl  

ln -s /etc/opt/remi/php72/php.ini /etc/php72.ini

ln -s  /etc/opt/remi/php72/php.d /etc/php72.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php72.sh
tput setaf 1
echo "PHP 7.2 Ready!"
tput sgr0 
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

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php56-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php56.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php56.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php56.tpl 

ln -s /etc/opt/remi/php56/php.ini /etc/php56.ini

ln -s  /etc/opt/remi/php56/php.d /etc/php56.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php56.sh

chmod 777 /opt/remi/php56/root/var/lib/php/session
tput setaf 1
echo "PHP 5.6 Ready!"
tput sgr0
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

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php55-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php55.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php55.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl /usr/local/vesta/data/templates/web/httpd/sk-php55.tpl 

ln -s /etc/opt/remi/php55/php.ini /etc/php55.ini

ln -s  /etc/opt/remi/php55/php.d /etc/php55.d

chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php55.sh
chmod 777 /opt/remi/php55/root/var/lib/php/session
tput setaf 1
echo "PHP 5.5 Ready!"
tput sgr0
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

curl -s http://mirror.skamasle.com/vestacp/PHP/sk-php54-centos.sh > /usr/local/vesta/data/templates/web/httpd/sk-php54.sh

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.stpl /usr/local/vesta/data/templates/web/httpd/sk-php54.stpl

ln -s /usr/local/vesta/data/templates/web/httpd/phpfcgid.tpl  /usr/local/vesta/data/templates/web/httpd/sk-php54.tpl  

ln -s /etc/opt/remi/php54/php.ini /etc/php54.ini

ln -s  /etc/opt/remi/php54/php.d /etc/php54.d


chmod +x /usr/local/vesta/data/templates/web/httpd/sk-php54.sh
tput setaf 1
echo "PHP 5.4 Ready!"
tput sgr0
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
