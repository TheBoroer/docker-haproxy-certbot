################################################
# Stage 1: use debian bullseye (ubuntu 20.04) 
#          for openssl 1.1.1 support for 2.9 
################################################
FROM debian:bullseye-slim as base

# https://github.com/docker-library/haproxy/blob/0c1da312a638ecef78b17c6919ec9780bc1f75e9/2.9/Dockerfile#L32-L34 
ENV HAPROXY_VERSION 2.9.13
ENV HAPROXY_URL https://www.haproxy.org/download/2.9/src/haproxy-2.9.13.tar.gz
ENV HAPROXY_SHA256 77d73e6bcda4863855442fe0d8f8dda12323043eeb49d0b3763f0b7314b05a93

# runtime dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    # @system-ca: https://github.com/docker-library/haproxy/pull/216
    ca-certificates \
    ; \
    rm -rf /var/lib/apt/lists/*

# roughly, https://salsa.debian.org/haproxy-team/haproxy/-/blob/732b97ae286906dea19ab5744cf9cf97c364ac1d/debian/haproxy.postinst#L5-6
RUN set -eux; \
    groupadd --gid 99 --system haproxy; \
    useradd \
    --gid haproxy \
    --home-dir /var/lib/haproxy \
    --no-create-home \
    --system \
    --uid 99 \
    haproxy \
    ; \
    mkdir /var/lib/haproxy; \
    chown haproxy:haproxy /var/lib/haproxy

# see https://sources.debian.net/src/haproxy/jessie/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    liblua5.4-dev \
    libpcre2-dev \
    libssl-dev \
    make \
    wget \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    wget -O haproxy.tar.gz "$HAPROXY_URL"; \
    echo "$HAPROXY_SHA256 *haproxy.tar.gz" | sha256sum -c; \
    mkdir -p /usr/src/haproxy; \
    tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1; \
    rm haproxy.tar.gz; \
    \
    makeOpts=' \
    TARGET=linux-glibc \
    USE_GETADDRINFO=1 \
    USE_LUA=1 LUA_INC=/usr/include/lua5.4 \
    USE_OPENSSL=1 \
    USE_PCRE2=1 USE_PCRE2_JIT=1 \
    USE_PROMEX=1 \
    \
    EXTRA_OBJS=" \
    " \
    '; \
    # https://salsa.debian.org/haproxy-team/haproxy/-/commit/53988af3d006ebcbf2c941e34121859fd6379c70
    dpkgArch="$(dpkg --print-architecture)"; \
    case "$dpkgArch" in \
    armel) makeOpts="$makeOpts ADDLIB=-latomic" ;; \
    esac; \
    \
    nproc="$(nproc)"; \
    eval "make -C /usr/src/haproxy -j '$nproc' all $makeOpts"; \
    eval "make -C /usr/src/haproxy install-bin $makeOpts"; \
    \
    mkdir -p /usr/local/etc/haproxy; \
    cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors; \
    rm -rf /usr/src/haproxy; \
    \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    \
    # smoke test
    haproxy -v

# https://www.haproxy.org/download/1.8/doc/management.txt
# "4. Stopping and restarting HAProxy"
# "when the SIGTERM signal is sent to the haproxy process, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent to the haproxy process"
STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

USER haproxy

# https://github.com/docker-library/haproxy/issues/200
WORKDIR /var/lib/haproxy
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]


##################################
# Stage 2: Build the final image
##################################
FROM base
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3-pip \
    ssl-cert \
    cron \
    libnl-utils \
    net-tools \
    iptables \
    socat \
    nano \
    orphan-sysvinit-scripts \
    rsyslog \
    wget

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/local/etc/haproxy /etc/haproxy \
    && sed -i '/#cron./c\cron.*                          \/proc\/1\/fd\/1'  /etc/rsyslog.conf \
    && sed -i '/#$ModLoad imudp/c\$ModLoad imudp'  /etc/rsyslog.conf \
    && sed -i '/#$UDPServerRun/c\$UDPServerRun 514'  /etc/rsyslog.conf \
    && sed -i '/$UDPServerRun 514/a $UDPServerAddress 127.0.0.1' /etc/rsyslog.conf \
    && sed -i '/cron.*/a local2.*                          \/proc\/1\/fd\/1' /etc/rsyslog.conf \
    && mv /usr/local/bin/docker-entrypoint.sh /haproxy-entrypoint.sh

# SSL Combined self-signed default haproxy cert
RUN touch /etc/ssl/certs/haproxy.pem
RUN cat /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key > /etc/ssl/certs/haproxy.pem

# Download p2cli dependency
RUN wget -O /usr/local/bin/p2 \
    https://github.com/wrouesnel/p2cli/releases/download/r5/p2 && \
    chmod +x /usr/local/bin/p2

# Install Certbot
RUN apt-get update \
    && apt-get install -y certbot \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup Certbot
RUN mkdir -p /etc/haproxy/certs.d
RUN mkdir -p /etc/letsencrypt
COPY configs/letsencrypt-cli.ini /etc/letsencrypt/cli.ini
COPY configs/letsencrypt-cli.ini /letsencrypt-cli.ini
COPY crons/certbot.cron /etc/cron.d/certbot
RUN ln -s /etc/cron.d/certbot /certbot.cron

# Setup helper scripts
COPY scripts/haproxy-refresh.sh /usr/local/bin/haproxy-refresh
COPY scripts/haproxy-restart.sh /usr/local/bin/haproxy-restart
COPY scripts/certbot-certonly.sh /usr/local/bin/certbot-certonly
COPY scripts/certbot-renew.sh /usr/local/bin/certbot-renew

# Fix script permissions
RUN chmod +x /usr/local/bin/haproxy-refresh \
    /usr/local/bin/haproxy-restart \
    /usr/local/bin/certbot-certonly \
    /usr/local/bin/certbot-renew

# Copy templates
COPY templates/haproxy.cfg.p2 /

# Add startup script
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

WORKDIR /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/etc/haproxy/haproxy.cfg"]
