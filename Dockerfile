FROM alpine:3.13

#ENV COMPOSER_HOME=/var/cache/composer
ENV PROJECT_ROOT=/sw6
ENV ARTIFACTS_DIR=/artifacts
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

ARG USER_ID
ARG GROUP_ID
ARG APP_ENV=prod
ARG DEBUG=true

RUN apk --no-cache add \
        nginx supervisor curl zip rsync xz coreutils \
        php7 php7-fpm \
        php7-ctype php7-curl php7-dom php7-fileinfo php7-gd \
        php7-iconv php7-intl php7-json php7-mbstring \
        php7-mysqli php7-openssl php7-pdo_mysql \
        php7-session php7-simplexml php7-tokenizer php7-xml php7-xmlreader php7-xmlwriter \
        php7-zip php7-zlib php7-phar php7-opcache php7-sodium git \
        gnu-libiconv \
        nodejs npm \
        bzip2-dev \
        gettext \
        ca-certificates \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libzip-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt-dev \
        pcre-dev \
        gmp-dev \
        bash \
        nano \
    && addgroup -g ${GROUP_ID} sw6 \
    && adduser -u ${USER_ID} -D -h $PROJECT_ROOT -G sw6 sw6 \
    && rm /etc/nginx/conf.d/default.conf \
    && mkdir -p /var/cache/composer

# Copy system configs
COPY config/etc /etc
COPY config/php7/conf.d $PHP_INI_DIR/conf.d
COPY config/php-fpm.d /usr/local/etc/php-fpm.d

# Make sure files/folders needed by the processes are accessible when they run under the sw6
RUN mkdir -p /var/{lib,tmp,log}/nginx \
    && chown -R sw6.sw6 /run /var/{lib,tmp,log}/nginx \
    && chown -R sw6.sw6 /var/cache/composer


COPY --from=composer:2.0.12 /usr/bin/composer /usr/bin/composer

WORKDIR $PROJECT_ROOT

USER sw6

#RUN composer global require hirak/prestissimo

#RUN composer require swiftmailer/swiftmailer

COPY --chown=sw6 composer.json .
COPY --chown=sw6 composer.lock .

RUN set -eux; \
    if [ "$APP_ENV" = "prod" ]; then \
        composer install --no-dev; \
    fi;

ADD --chown=sw6 . .

RUN APP_URL="http://localhost" DATABASE_URL="" bin/console assets:install \
    && rm -Rf var/cache \
    && touch install.lock \
    && mkdir -p var/cache

ENV INSTANCE_ID=u5zucrdjkx7yw6mtfwhpwzmwfgsxg4wgnmt83v74ec988mdz
# Expose the port nginx is reachable on
EXPOSE 8000

# Let supervisord start nginx & php-fpm
ENTRYPOINT ["./bin/entrypoint.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8000/fpm-ping
