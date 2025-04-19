#!/bin/bash

# Do some setup on first run (when the config file doesn't exist yet)
if ! test -e /etc/haproxy/haproxy.cfg; then
  # symlink libnl-3 to libnl (haproxy 2.4+ docker image issue)
  if [ ! -e /usr/lib/x86_64-linux-gnu/libnl/cli/qdisc/plug.so ] && [ -e /usr/lib/x86_64-linux-gnu/libnl-3/cli/qdisc/plug.so ]; then
    mkdir /usr/lib/x86_64-linux-gnu/libnl/
    ln -s /usr/lib/x86_64-linux-gnu/libnl-3/* /usr/lib/x86_64-linux-gnu/libnl/
  fi

  if [ ! -z "$CERTBOT_ENABLED" ]; then
    if [ -z "$CERTBOT_EMAIL" ]; then
      echo "WARNING: CERTBOT_EMAIL is required and cannot be null or empty."

    else
      # acme.sh --register-account \
      #   --server ${ACMESH_SERVER:-"letsencrypt"} \
      #   -m ${CERTBOT_EMAIL} \
      #   --agree-tos

      if [ -z "$CERTBOT_HOSTNAME" ]; then
        echo "WARNING: CERTBOT_HOSTNAME is required and cannot be null or an empty string."
      else
        # Build a single command string to run all certbot/acme.sh commands sequentially
        command_string=""

        for hostname in $CERTBOT_HOSTNAME; do
          echo "Adding to command chain: certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL}"
          # echo "Adding to command chain: acme.sh --issue -d ${hostname} --standalone --httpport 8080"

          if [ -z "$command_string" ]; then
            command_string="certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL}"
            # command_string="acme.sh --issue -d ${hostname} --standalone --httpport 8080"
          else
            command_string="${command_string} && certbot-certonly --domain ${hostname} --email ${CERTBOT_EMAIL}"
            # command_string="${command_string} && acme.sh --issue -d ${hostname} --standalone --httpport 8080"
          fi
        done

        # Add the final haproxy-refresh to the command chain
        command_string="${command_string} && haproxy-refresh"

        # Execute the full command chain
        echo "Executing chained certbot commands..."
        eval $command_string &

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
if [ "$CUSTOM_HAPROXY_CONFIG" != "true" ]; then
  echo "Generating /etc/haproxy/haproxy.cfg ..."
  p2 -t /haproxy.cfg.p2 >/etc/haproxy/haproxy.cfg
else
  echo "WARNING: CUSTOM_HAPROXY_CONFIG is set to true. No haproxy.cfg file will be generated on container start."
fi

if [ "$CUSTOM_CERTBOT_CONFIG" != "true" ]; then
  echo "Generating /etc/letsencrypt/cli.ini ..."
  p2 -t /certbot-cli.ini.p2 >/etc/letsencrypt/cli.ini
else
  echo "WARNING: CUSTOM_CERTBOT_CONFIG is set to true. No cli.ini file will be generated on container start."
fi

#start logging
service rsyslog restart

#start crontab
service cron restart

echo "Starting haproxy..."
exec /haproxy-entrypoint.sh "$@"
