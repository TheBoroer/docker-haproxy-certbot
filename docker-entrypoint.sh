#!/bin/bash

# haproxy not directly configured within /etc/haproxy/haproxy.cfg
if ! test -e /etc/haproxy/haproxy.cfg; then

  # Generate config from env vars
  p2 -t /haproxy.cfg.p2 >/etc/haproxy/haproxy.cfg

  # copy letsencrypt-cli.ini to /etc/letsencrypt/cli.ini
  cp /letsencrypt-cli.ini /etc/letsencrypt/cli.ini

  # symlink libnl-3 to libnl
  # if [ ! -e /usr/lib/x86_64-linux-gnu/libnl/cli/qdisc/plug.so ] && [ -e /usr/lib/x86_64-linux-gnu/libnl-3/cli/qdisc/plug.so ]; then
  #   mkdir /usr/lib/x86_64-linux-gnu/libnl/
  #   ln -s /usr/lib/x86_64-linux-gnu/libnl-3/* /usr/lib/x86_64-linux-gnu/libnl/
  # fi

  if [ ! -z "$CERTBOT_ENABLED" ]; then
    if [ -z "$CERTBOT_EMAIL" ]; then
      echo "WARNING: CERTBOT_EMAIL is required and cannot be null or empty."

    else
      if [ -z "$CERTBOT_HOSTNAME" ]; then
        echo "WARNING: CERTBOT_HOSTNAME is required and cannot be null or an empty string."
      else
        for hostname in $CERTBOT_HOSTNAME; do
          echo "Queued to run in 10 seconds: certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL}"

          # wait 10 seconds then run certbot (enough time for haproxy to startup)
          sleep 10 && certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL} && haproxy-refresh &
          # wait 10 seconds before queuing another certbot instance
          sleep 10
          # TODO: instead of sleeping, chain all the certbot cli commands to run back to back
        done

        # Add certbot to cron
        crontab /certbot.cron
      fi
    fi
  else
    # Add crontab
    crontab /var/crontab.txt
  fi

  chmod 600 /etc/crontab
fi

#start logging
service rsyslog restart

#start crontab
service cron restart

exec /haproxy-entrypoint.sh "$@"
