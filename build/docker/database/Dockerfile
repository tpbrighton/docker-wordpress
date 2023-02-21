ARG MARIADB_VERSION="10.7"
FROM "mariadb:${MARIADB_VERSION}" AS mariadb
MAINTAINER Zan Baldwin "hello@zanbaldwin.com"

COPY "./php.conf" "/etc/mysql/conf.d/php.cnf"
COPY "./memory.conf" "/etc/mysql/conf.d/memory.cnf"
