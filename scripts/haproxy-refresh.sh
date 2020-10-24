#!/bin/bash

HA_PROXY_DIR=/etc/haproxy
LE_DIR=/etc/letsencrypt/live
DOMAINS=$(ls ${LE_DIR})

# update certs for HA Proxy
for DOMAIN in ${DOMAINS}
do
  if [ "$DOMAIN" != "README" ]; then
    cat ${LE_DIR}/${DOMAIN}/fullchain.pem ${LE_DIR}/${DOMAIN}/privkey.pem > ${HA_DIR}/${DOMAIN}.pem
    echo -e "set ssl cert ${HA_DIR}/${DOMAIN}.pem <<\n$(cat ${HA_DIR}/${DOMAIN}.pem)\n" | socat stdio /var/run/haproxy
    echo -e "commit ssl cert ${HA_DIR}/${DOMAIN}.pem" | socat stdio /var/run/haproxy
  fi
done

# restart haproxy
exec /usr/local/bin/haproxy-restart
