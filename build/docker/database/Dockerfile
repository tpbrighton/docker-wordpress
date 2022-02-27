ARG MYSQL_VERSION="8.0.25"

FROM "mysql:${MYSQL_VERSION}"
MAINTAINER Zan Baldwin "hello@zanbaldwin.com"

COPY "./php.conf" "/etc/mysql/conf.d/php.cnf"
COPY "./memory.conf" "/etc/mysql/conf.d/memory.cnf"
