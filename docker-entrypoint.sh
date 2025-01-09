#!/bin/bash

# Do some setup on first run (when the config file doesn't exist yet)
if ! test -e /etc/haproxy/haproxy.cfg; then
  # copy letsencrypt-cli.ini to /etc/letsencrypt/cli.ini
  cp /letsencrypt-cli.ini /etc/letsencrypt/cli.ini

  # symlink libnl-3 to libnl (haproxy 2.4+ docker image issue)
  if [ ! -e /usr/lib/x86_64-linux-gnu/libnl/cli/qdisc/plug.so ] && [ -e /usr/lib/x86_64-linux-gnu/libnl-3/cli/qdisc/plug.so ]; then
    mkdir /usr/lib/x86_64-linux-gnu/libnl/
    ln -s /usr/lib/x86_64-linux-gnu/libnl-3/* /usr/lib/x86_64-linux-gnu/libnl/
  fi

  if [ ! -z "$CERTBOT_ENABLED" ]; then
    if [ -z "$CERTBOT_EMAIL" ]; then
      echo "WARNING: CERTBOT_EMAIL is required and cannot be null or empty."

    else
      if [ -z "$CERTBOT_HOSTNAME" ]; then
        echo "WARNING: CERTBOT_HOSTNAME is required and cannot be null or an empty string."
      else
        for hostname in $CERTBOT_HOSTNAME; do
          echo "Queued to run in 5 seconds: certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL}"

          # wait a bit then run certbot (enough time for haproxy to startup)
          sleep 5 && certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL} && haproxy-refresh &
          # wait a bit before queuing another certbot instance
          sleep 5
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

# Generate the haproxy config file
if [ "$CONFIG_DISABLE" != "true" ]; then
  p2 -t /haproxy.cfg.p2 >/etc/haproxy/haproxy.cfg
else
  echo "WARNING: CONFIG_DISABLE is set to true. No config file will be generated on container start."
fi

#start logging
service rsyslog restart

#start crontab
service cron restart

exec /haproxy-entrypoint.sh "$@"
