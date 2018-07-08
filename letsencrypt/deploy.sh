#!/bin/sh

rm -rf /etc/openldap/certs/server.{key,crt}
cp -f /etc/letsencrypt/live/ldap.codingcafe.org/*.pem /etc/openldap/certs/

chmod 640 /etc/openldap/certs/*.pem
chgrp ldap /etc/openldap/certs/*.pem
