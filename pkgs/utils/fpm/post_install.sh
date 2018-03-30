#!/bin/sh

set -e

cd /etc/ld.so.conf.d
[ -d '/codingcafe.conf.d' ] && echo 'include codingcafe.conf.d/*.conf' > /etc/ld.so.conf.d/codingcafe.conf || rm -f codingcafe.conf
ldconfig
