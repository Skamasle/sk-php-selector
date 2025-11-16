#!/bin/bash
# Adding php wrapper
user="$1"
domain="$2"
ip="$3"
home_dir="$4"
docroot="$5"

wrapper_script="#!/bin/sh
PHPRC=/usr/local/lib
export PHPRC
export PHP_FCGI_MAX_REQUESTS=500
export PHP_FCGI_CHILDREN=10
exec  /usr/bin/php81-cgi
"
wrapper_file="$home_dir/$user/web/$domain/cgi-bin/fcgi-starter"

echo "$wrapper_script" > $wrapper_file
chown $user:$user $wrapper_file
chmod -f 751 $wrapper_file

exit 0
