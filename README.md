# sk-php-selector
PHP selector for centos 6/7 

# RUN AT YOUR OWN RISK

This install php 5.4, 5.5, 5.6, 7.0, 7.1, 7.2, 7.3, 7.4 and 8.0 in your centos 6 and centos 7

**Use sk-php-selector2.sh, in this you can select what php version install
sk-php-selector3.sh is same as sk-php-selector2.sh but with simplified code, now in testing **

# So you can select just one version runing it as:

bash sk-php-selector2.sh php72

# Or install multiple version

bash sk-php-selector2.sh php56 php71

# or install all

bash sk-php-selector2.sh all

This works fine, the configuration of php need some work so try firts in test enviroment

------------

This can break phpmyadmin, in this case you need delete some mod_php files in /etc/httpd/conf.d/ you can move out all php??.conf just leave php.conf ( not delete maybe you need restore it )

This is aleatory and need more debugin, not always was broken so I cant say you exactly, but the solution is wasy

# Diferences between version 2 and 3

This work in same way, sk-php-selector3.sh have short code, and sk-php-selector2.sh have a lite more code, but this one  you can modify in easy way, and  you can add for each php version diferent modules, just edit yum install line as your need, if you need specific module in php 7 and orther in php 5 and want customice it use sk-php-selector2.sh

sk-php-selector is a first version may work, but I not recomend you use it
