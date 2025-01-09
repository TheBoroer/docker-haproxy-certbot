FROM haproxy:2.4.27

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

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/etc/haproxy/haproxy.cfg"]
