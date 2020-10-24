#!/bin/bash

/usr/bin/certbot certonly -c /etc/letsencrypt/cli.ini "$@"
