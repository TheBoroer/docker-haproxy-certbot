# HAProxy with Certbot

Docker Container with haproxy and certbot.

## Setup and Create Container

This will create the haproxy-certbot container. Note that only the inbound ports
for 80 and 443 are exposed.

```bash
docker run -d \
  --restart=always \
  --name haproxy-certbot \
  -p 80:80 \
  -p 443:443 \
  -v /docker/haproxy/haproxy.cfg:/etc/haproxy/haproxy.cfg \
  -v /docker/haproxy/letsencrypt:/etc/letsencrypt \
  -v /docker/haproxy/certs.d:/etc/haproxy/certs.d \
  boro/haproxy-certbot
```

It is important to note the mapping of the 3 volumes in the above command. This
ensures that all non-persistent variable data is not maintained in the container
itself.

### Mounted Volumes

* `/etc/haproxy/haproxy.cfg` - The configuration file location for haproxy.cfg
* `/etc/letsencrypt` - The directory that Let's Encrypt will store it's
  configuration, certificates and private keys. **It is of significant
  importance that you maintain a backup of this folder in the event the data is
  lost or corrupted.**
* `/etc/haproxy/certs.d` - The directory that this container will
  store the processed certs/keys from Let's Encrypt after they have been
  converted into a format that HAProxy can use. This is automatically done at
  each refresh and can also be manually initiated. This volume is not as
  important as the previous as the certs used by HAProxy can be regenerated
  again based on the contents of the letsencrypt folder.

## Container Helper Scripts

There are a handful of helper scripts to ease the amount of configuration
parameters needed to administer this container.

#### Add a New Cert

This will add a new cert using a certbot config that is compatible with the
haproxy config template below. After creating the cert, you should run the
refresh script referenced below to initialize haproxy to use it. After adding
the cert and running the refresh script, no further action is needed.

***This example assumes you named you haproxy-certbot container using the same
name as above when it was created. If not, adjust appropriately.***

```bash
# request certificate from let's encrypt
docker exec haproxy-certbot certbot-certonly \
  --domain example.com \
  --domain www.example.com \
  --email user@domain.com \
  --dry-run

# create/update haproxy formatted certs in certs.d and then restart haproxy
docker exec haproxy-certbot haproxy-refresh
```

*After testing the setup, remove `--dry-run` to generate a live certificate*

#### Renew a Cert

Renewing happens automatically but should you choose to renew manually, you can
do the following.

***This example assumes you named you haproxy-certbot container using the same
name as above when it was created. If not, adjust appropriately.***

```bash
docker exec haproxy-certbot certbot-renew \
  --dry-run
```

*After testing the setup, remove `--dry-run` to refresh a live certificate*

#### Create/Refresh Certs used by HAProxy from Let's Encrypt

This will parse and individually concatenate all the certs found in
`/etc/letsencrypt/live` directory into the folder
`/etc/haproxy/certs.d`. It additionally will restart the HAProxy
service so that the new certs are active.

When HAProxy is restarted, the system will queue requests using tc and libnl and
minimal to 0 interruption of the HAProxy services is expected.

See [this blog entry](https://engineeringblog.yelp.com/2015/04/true-zero-downtime-haproxy-reloads.html) for more details.

**Note: This process automatically happens whenever the cron job runs to refresh
the certificates that have been registered.**

```bash
docker exec haproxy-certbot haproxy-refresh
```

## Environment Variables

HAProxy can be configured by modifying the following env variables,
either when running the container or in a `docker-compose.yml` file.

* `CERTBOT_ENABLED` The option to enable or disable running the certbot for generating and configuring automatic Let's Encrypt SSL certificates - default `false`
* `STATS_PORT` The port to bind statistics to - default `1936`
* `STATS_AUTH` The authentication details (written as `user:password` for the statistics page - default `admin:admin`
* `FRONTEND_NAME` The label of the frontend - default `http-frontend`
* `FRONTEND_PORT` The port to bind the frontend to - default `5000`
* `FRONTEND_MODE` Frontend mode - default `http`
* `PROXY_PROTOCOL_ENABLED` The option to enable or disable accepting proxy protocol (`true` stands for enabled, `false` or anything else for disabled) - default `false`
* `COOKIES_ENABLED` The option to enable or disable cookie-based sessions (`true` stands for enabled, `false` or anything else for disabled) - default `false`
* `BACKEND_NAME` The label of the backend - default `http-backend`
* `BACKENDS` The list of `server_ip:server_listening_port` to be load-balanced by HAProxy, separated by space - by default it is not set
* `BACKENDS_PORT` Port to use when `BACKENDS` are specified without port - by default `80`
* `BACKENDS_MODE` Backends mode - default `http`
* `BALANCE` The algorithm used for load-balancing - default `roundrobin`
* `SERVICE_NAMES` An optional prefix for services to be included when discovering services separated by space. - by default it is not set
* `LOGGING` Override logging ip address:port - default is udp `127.0.0.1:514` inside container
* `LOG_LEVEL` Set haproxy log level, default is `notice` ( only send important events ). Can be: `emerg`,`alert`,`crit`,`err`,`warning`,`notice`,`info`,`debug`
* `TIMEOUT_CONNECT` the maximum time to wait for a connection attempt to a VPS to succeed. Default `5000` ms
* `TIMEOUT_CLIENT` timeouts apply when the client is expected to acknowledge or send data during the TCP process. Default `50000` ms
* `TIMEOUT_SERVER` timeouts apply when the server is expected to acknowledge or send data during the TCP process. Default `50000` ms
* `HTTPCHK` The HTTP method and uri used to check on the servers health - default `HEAD /`
* `HTTPCHK_EXPECT` The HTTP check option's expect rule - default `status 200`
* `INTER` parameter sets the interval between two consecutive health checks. If not specified, the default value is `2s`
* `FAST_INTER` parameter sets the interval between two consecutive health checks when the server is any of the transition state (read above): UP - transitionally DOWN or DOWN - transitionally UP. If not set, then `INTER` is used.
* `DOWN_INTER` parameter sets the interval between two consecutive health checks when the server is in the DOWN state. If not set, then `INTER` is used.
* `RISE` number of consecutive valid health checks before considering the server as UP. Default value is `2`
* `FALL` number of consecutive invalid health checks before considering the server as DOWN. Default value is `3`
