ARG NGINX_VERSION="1.19.10-alpine"
FROM "nginx:${NGINX_VERSION}" AS development
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

RUN    rm -rf '/etc/nginx/conf.d' \
    && mkdir -p '/etc/nginx/conf.d' \
    && mkdir -p '/srv/public' \
    && [ -e '/srv/public/index.php' ] || touch '/srv/public/index.php'

COPY './acme.conf' '/etc/nginx/acme.conf'
COPY './challenges.conf' '/etc/nginx/challenges.conf'
COPY './ssl.conf' '/etc/nginx/ssl.conf'
COPY './server.conf' '/etc/nginx/conf.d/server.conf'

# Create a new user with UID#1000 (the UID that the user on the host machine is likely to have).
# Instruct Nginx to run as that user.
ARG NGINX_USER="tpb"
# And setup the Nginx configuration with the specified domain.
ARG DOMAIN="transpridebrighton.org"
RUN    apk add --no-cache --virtual .user-build-deps shadow \
    && (userdel 'nginx' || true) \
    && useradd --no-create-home --uid 1000 --user-group "${NGINX_USER}" \
    && sed -i -E "s/user\s+nginx/user ${NGINX_USER}/g" '/etc/nginx/nginx.conf' \
    && apk del '.user-build-deps' \
    && sed -i -e "s/\${DOMAIN}/${DOMAIN}/g" '/etc/nginx/conf.d/server.conf' \
    && sed -i -e "s/\${DOMAIN}/${DOMAIN}/g" '/etc/nginx/ssl.conf'

EXPOSE 80
EXPOSE 443
WORKDIR "/srv/public"
CMD [ "nginx", "-g", "daemon off;" ]
