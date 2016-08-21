FROM alpine:latest
MAINTAINER Benoît Pourre <benoit.pourre@gmail.com>

EXPOSE 80 443

ENV HOME=/root

ENV NGINX_VERSION 1.10.1

ENV GPG_KEYS B0F4253373F8F6F510D42178520A9993A1C052F8
ENV CONFIG "\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_geoip_module=dynamic \
	--with-threads \
	--with-http_slice_module \
	--with-file-aio \
	--with-http_v2_module \
	--with-ipv6 \
	"

RUN \
	addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		geoip-dev \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& ./configure $CONFIG \
	&& make \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& mkdir /etc/nginx/sites-enabled \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	&& apk add --no-cache gettext

# install packages
RUN apk --update --no-progress add --no-cache \
	ssmtp tzdata curl \
	php5-fpm php5-json php5-curl php5-iconv php5-ctype php5-dom php5-intl \
	php5-gd php5-zlib php5-openssl php5-mcrypt php5-phar \
	php5-xmlreader php5-xml php5-exif php5-cli php5-ldap php5-xmlrpc php5-xsl \
	php5-pdo_mysql php5-pdo_pgsql php5-zip php5-bz2 php5-apcu php5-pcntl php5-gmp php5-posix && \
	apk add --update -X http://nl.alpinelinux.org/alpine/edge/testing php5-redis && \
	apk add --update -X http://nl.alpinelinux.org/alpine/edge/community php5-imagick && \
	rm -rf /var/cache/apk/*

ENV TZ Europe/Paris
RUN echo "$TZ" > /etc/timezone && \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/php.ini && \
	sed -i -e "s/;sendmail_path = /sendmail_path = sendmail -t -i/g" /etc/php5/php.ini && \
	sed -i -e "s/listen = 127\.0\.0\.1:9000/listen = \/var\/run\/php-fpm.sock/g" /etc/php5/php-fpm.conf && \
	sed -i -e "s/;listen.owner = nobody/listen.owner = nginx/g" /etc/php5/php-fpm.conf && \
	sed -i -e "s/;listen.group = nobody/listen.group = nginx/g" /etc/php5/php-fpm.conf && \
	sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/php-fpm.conf && \
	echo "date.timezone = $TZ" >>  /etc/php5/php.ini

# install owncloud
ENV OWNCLOUD_VERSION 9.1.0
ENV OWNCLOUD_PACKAGE owncloud-$OWNCLOUD_VERSION.tar.bz2
ENV OWNCLOUD_URL https://download.owncloud.org/community/$OWNCLOUD_PACKAGE
RUN cd /usr/share/nginx/html \
    && curl -LOs $OWNCLOUD_URL \
    && tar xjf $OWNCLOUD_PACKAGE \
    && rm $OWNCLOUD_PACKAGE \
    && mkdir -p /usr/share/nginx/html/owncloud/config /usr/share/nginx/html/owncloud/data \
    && chmod 0770 /usr/share/nginx/html/owncloud/data \
    && chown -R nobody:nobody /usr/share/nginx/html/owncloud/data /usr/share/nginx/html/owncloud/config /usr/share/nginx/html/owncloud 


# Setup Volume
VOLUME ["/var/log/nginx", "/usr/share/nginx/html/owncloud/config", "/usr/share/nginx/html/owncloud/data"]

ADD start.sh /start.sh

CMD ["/bin/sh", "/start.sh"]

ADD conf.d/ /etc/nginx/conf.d/

ADD php.ini /etc/php5/php.ini

ADD nginx.conf /etc/nginx/nginx.conf

ADD nginx-site.conf /etc/nginx/sites-enabled/default.conf

