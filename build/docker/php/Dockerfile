ARG PHP_VERSION="7.4-fpm-alpine3.13"
FROM "php:${PHP_VERSION}" AS development
MAINTAINER Zan Baldwin "hello@zanbaldwin.com"

# Compiles a statically-linked version of the init (PID 1) process bundled with Docker since v1.13 (API v1.25).
# Alpine uses musl instead of glibc, so it's best not to use the dynamically-linked version.
# See https://github.com/krallin/tini/issues/8#issuecomment-146135930
RUN    apk add --no-cache --virtual .tini-build-deps cmake gcc git libc-dev make \
    && git clone 'git://github.com/krallin/tini.git' '/tmp/tini' \
    && ( \
        cd '/tmp/tini'; \
        git checkout "$(git describe --tags)"; \
        export CFLAGS='-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37'; \
        cmake . && make; \
    ) \
    && mv '/tmp/tini/tini-static' '/tini' && chmod +x '/tini' \
    && rm -rf '/tmp/tini' \
    && apk del '.tini-build-deps'
ENTRYPOINT [ "/tini", "--" ]

# Install all standardised PHP extensions (zip files, image manipulation, caching, database access, etc) that
# WordPress plugins are likely to use.
RUN    apk add --no-cache --upgrade --virtual ".extension-build-deps" \
        giflib-dev gmp-dev icu-dev libffi-dev libjpeg-turbo-dev libpng-dev libwebp-dev libxml2-dev libzip-dev \
    && apk add --no-cache --upgrade --virtual ".extension-runtime-deps" \
        giflib gmp icu libffi libjpeg-turbo libpng libwebp libxml2 libzip \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install \
        ffi gd gmp intl opcache pcntl pdo_mysql sockets xml zip \
    && apk del ".extension-build-deps"

RUN    apk add --no-cache --upgrade --virtual .pecl-build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && echo "extension=redis.so" > "/usr/local/etc/php/conf.d/pecl-redis.ini" \
    && apk del .pecl-build-deps

# Composer (see https://github.com/composer/docker/blob/master/1.8/Dockerfile)
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME="/tmp"
ARG COMPOSER_VERSION="2.0.8"
RUN    curl --silent --fail --location --retry 3 --output "/tmp/installer.php.hash" --url "https://composer.github.io/installer.sig" \
    && curl --silent --fail --location --retry 3 --output "/tmp/installer.php" --url "https://getcomposer.org/installer" \
    && php -r "if (hash_file('sha384', '/tmp/installer.php') === file_get_contents('/tmp/installer.php.hash')) { echo 'Installer verified.' . PHP_EOL; } else { echo 'Installer corrupt.' . PHP_EOL; unlink('/tmp/installer.php'); exit(1); }" \
    && php "/tmp/installer.php" --no-ansi --install-dir="/sbin" --filename="composer" --version="${COMPOSER_VERSION}" \
    && composer --no-ansi --no-interaction --version \
    && rm -f "installer.php.hash" "installer.php"

# Create a new user with UID#1000 (the UID that the user on the host server is likely to have) and
# instruct PHP to run as that user.
RUN    apk add --no-cache --virtual .user-build-deps shadow \
    && useradd --no-create-home --uid 1000 --user-group "tpb" \
    && sed -i -e "s/www-data/tpb/g" "/usr/local/etc/php-fpm.d/www.conf" \
    && apk del '.user-build-deps'

COPY "./php.ini" "/usr/local/etc/php/php.ini"
COPY "./emergency_restart.conf" "/usr/local/etc/php-fpm.d/emergency_restart.conf"

WORKDIR "/srv"
CMD [ "php-fpm", "--nodaemonize" ]
