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
* `CERTBOT_EMAIL` Required Email for expiry and other email notifications from letsencrypt - default ``
* `CERTBOT_HOSTNAME` Hostname to request a certificate for. Supports multiple hostnames separated by a single space - default: ``
* `STATS_PORT` The port to bind statistics to - default `1936`
* `STATS_AUTH` The authentication details (written as `user:password` for the statistics page - default `admin:admin`
* `FRONTEND_NAME` The label of the frontend - default `http-frontend`
* `FRONTEND_HTTP_PORT` The port to bind the frontend HTTP to - default `80`
* `FRONTEND_HTTPS_PORT` The port to bind the frontend HTTPS to - default `443`
* `REDIRECT_TO_HTTPS` Setting to redirect HTTP traffic to HTTPS - default `false`
* `FRONTEND_MODE` Frontend mode - default `http`
* `DNS_HOLD_VALID` Time period to cache last DNS resolution for before needing to do another dns fetch - default `10s`
* `PROXY_PROTOCOL_ENABLED` The option to enable or disable accepting proxy protocol (`true` stands for enabled, `false` or anything else for disabled) - default `false`
* `COOKIES_ENABLED` The option to enable or disable cookie-based sessions (`true` stands for enabled, `false` or anything else for disabled) - default `false`
* `BACKEND_NAME` The label of the backend - default `http-backend`
* `BACKENDS` The list of `server_ip:server_listening_port` to be load-balanced by HAProxy, separated by space - by default it is not set
* `BACKENDS_PORT` Port to use when `BACKENDS` are specified without port - by default `80`
* `BACKENDS_MODE` Backends mode - default `http`
* `BACKEND_HTTP_REUSE` - default `safe`
* `BACKEND_HTTP_NO_DELAY` - default `false`
* `FRONTEND_OPTIONS` Additional line(s) to be added to the backend block - default is blank
* `BACKEND_OPTIONS` Additional line(s) to be added to the backend block - default is blank
* `BALANCE` The algorithm used for load-balancing - default `roundrobin`
* `SERVICE_NAMES` An optional prefix for services to be included when discovering services separated by space. - by default it is not set
* `LOGGING` Override logging ip address:port - default is udp `127.0.0.1:514` inside container
* `LOG_LEVEL` Set haproxy log level, default is `notice` ( only send important events ). Can be: `emerg`,`alert`,`crit`,`err`,`warning`,`notice`,`info`,`debug`
* `TIMEOUT_CONNECT` Set the maximum time to wait for a connection attempt to a server to succeed. - default `5s`
* `TIMEOUT_CLIENT` Set the maximum inactivity time on the client side. - default `50s`
* `TIMEOUT_SERVER` Set the maximum inactivity time on the server side. - default `50s`
* `TIMEOUT_HTTP_REQUEST` Set the maximum allowed time to wait for a complete HTTP request - default `10s`
* `TIMEOUT_HTTP_KEEP_ALIVE` Set the maximum allowed time to wait for a new HTTP request to appear - default `2s`
* `TIMEOUT_QUEUE` Set the maximum time to wait in the queue for a connection slot to be free - default `5s`
* `TIMEOUT_TUNNEL` Set the maximum inactivity time on the client and server side for tunnels. - default `2m`
* `TIMEOUT_CLIENT_FIN` Set the inactivity timeout on the client side for half-closed connections. - default `1s`
* `TIMEOUT_SERVER_FIN` Set the inactivity timeout on the server side for half-closed connections. - default `1s`
* `HTTPCHECK` The HTTP method and uri used to check on the servers health - default `meth HEAD uri / ver HTTP/1.1`
* `HTTPCHECK_EXPECT` The HTTP check option's expect rule - default `status 200`
* `INTER` parameter sets the interval between two consecutive health checks. If not specified, the default value is `2s`
* `FAST_INTER` parameter sets the interval between two consecutive health checks when the server is any of the transition state (read above): UP - transitionally DOWN or DOWN - transitionally UP. If not set, then `INTER` is used.
* `DOWN_INTER` parameter sets the interval between two consecutive health checks when the server is in the DOWN state. If not set, then `INTER` is used.
* `RISE` number of consecutive valid health checks before considering the server as UP. Default value is `2`
* `FALL` number of consecutive invalid health checks before considering the server as DOWN. Default value is `3`
