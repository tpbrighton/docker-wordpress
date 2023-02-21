ARG PHP_VERSION="7.4-fpm-alpine3.13"
FROM "php:${PHP_VERSION}" AS development
MAINTAINER Zan Baldwin "hello@zanbaldwin.com"

# Compiles a statically-linked version of the init (PID 1) process bundled with Docker since v1.13 (API v1.25).
# Alpine uses musl instead of glibc, so it's best not to use the dynamically-linked version.
# See https://github.com/krallin/tini/issues/8#issuecomment-146135930
RUN    apk add --no-cache --virtual .tini-build-deps cmake gcc git libc-dev make \
    && git clone 'https://github.com/krallin/tini.git' '/tmp/tini' \
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
RUN    apk add --no-cache --upgrade --virtual '.extension-build-deps' \
        giflib-dev gmp-dev icu-dev libffi-dev libjpeg-turbo-dev libpng-dev libwebp-dev libxml2-dev libzip-dev \
    && apk add --no-cache --upgrade --virtual '.extension-runtime-deps' \
        giflib gmp icu libffi libjpeg-turbo libpng libwebp libxml2 libzip \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install \
        exif ffi gd gmp intl mysqli opcache pcntl pdo_mysql sockets xml zip \
    && apk del '.extension-build-deps'

RUN    apk add --no-cache --upgrade --virtual '.pecl-build-deps' $PHPIZE_DEPS imagemagick-dev \
    && apk add --no-cache --upgrade --virtual '.pecl-runtime-deps' imagemagick \
    && pecl install imagick && docker-php-ext-enable imagick \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del '.pecl-build-deps'

# Composer (see https://github.com/composer/docker/blob/master/1.8/Dockerfile)
RUN    curl --silent --fail --location --retry 3 --output '/tmp/installer.sig' --url 'https://composer.github.io/installer.sig' \
    && curl --silent --fail --location --retry 3 --output '/tmp/installer.php' --url 'https://getcomposer.org/installer' \
    && php -r 'if (hash_file("sha384", "/tmp/installer.php") === file_get_contents("/tmp/installer.sig")) { echo "Installer verified." . PHP_EOL; } else { echo "Installer corrupt." . PHP_EOL; exit(1); }' \
    && php '/tmp/installer.php' --no-ansi --install-dir='/sbin' --filename='composer' \
    && rm -f '/tmp/installer.sig' '/tmp/installer.php'

# Create a new user with UID#1000 (the UID that the user on the host machine is likely to have).
# Instruct PHP to run as that user.
ARG PHP_USER="tpb"
RUN    apk add --no-cache --virtual .user-build-deps shadow \
    && (userdel 'www-data' || true) \
    && useradd --no-create-home --uid 1000 --user-group "${PHP_USER}" \
    && sed -i -e "s/www-data/${PHP_USER}/g" '/usr/local/etc/php-fpm.d/www.conf' \
    && apk del '.user-build-deps'

COPY './php.ini' '/usr/local/etc/php/php.ini'
COPY './emergency_restart.conf' '/usr/local/etc/php-fpm.d/emergency_restart.conf'

EXPOSE 9000
WORKDIR '/srv'
CMD [ "php-fpm", "--nodaemonize" ]
