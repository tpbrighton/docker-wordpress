ARG REDIS_VERSION="7.0"
FROM "redis:${REDIS_VERSION}" AS redis
MAINTAINER Zan Baldwin "hello@zanbaldwin.com"

COPY "./redis.conf" "/usr/local/etc/redis/redis.conf"
CMD [ "redis-server", "/usr/local/etc/redis/redis.conf" ]
