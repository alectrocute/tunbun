# tunbun

`tunbun` runs [frp](https://github.com/fatedier/frp) in Docker so you can:

1. run a lightweight tunnel server on Bunny.net Magic Containers, and
2. forward traffic from Bunny to services in your homelab via a client container.

## Quick architecture

- **Server (Bunny.net Magic Container):** `TUNBUN_MODE=server`
- **Client (homelab Docker host):** `TUNBUN_MODE=client`
- **Auth:** shared `TUNBUN_TOKEN` on both sides
- **Routing:** `TUNBUN_LOCAL_PORT_TO_FQDN` maps `localPort:hostname`

Example mapping:

- `8080:app1-abc123.b-cdn.net` -> requests for that hostname go to `localhost:8080` on your homelab host.

## 1) Simple Bunny.net setup (server)

### Create the Magic Container

Use image `alectrocute/tunbun:latest` and set:

- `TUNBUN_MODE=server`
- `TUNBUN_TOKEN=<long-random-secret>`
- `TUNBUN_DASHBOARD_USER=admin`
- `TUNBUN_DASHBOARD_PASSWORD=changeme`

### Expose ports with Anycast endpoints

Create endpoints so Bunny can reach your server container:

- `7000 -> 7000` (frp control channel from client)
- `7500 -> 7500` (frps dashboard)
- `80 -> 80` (HTTP ingress from pull zones)

Important: Make sure port 80 is set as an Anycast endpoint, not CDN. If you don't, your pull-zone origin will be set to Bunny CDN and you will get 508 loops.

Keep the `7000` endpoint/IP for `TUNBUN_SERVER_ADDR` in your client config.

### Pull zone origin

For each Bunny pull zone you want to tunnel:

- set **Origin URL** to your Anycast endpoint for port `80`
- enable forwarding of the pull-zone hostname to origin (so origin receives `Host: <zone>.b-cdn.net`)
- disable/override all caching

Do not set a Bunny CDN hostname as the origin (that causes 508 loops).

## 2) Simple homelab Docker Compose setup (client)

Use this as your baseline `docker-compose.yml`:

```yaml
services:
  tunbun-client:
    image: alectrocute/tunbun:latest
    container_name: tunbun-client
    restart: unless-stopped
    network_mode: host
    environment:
      TUNBUN_MODE: client
      TUNBUN_SERVER_ADDR: YOUR_BUNNY_ANYCAST_IP_OR_HOST_FOR_7000
      TUNBUN_SERVER_PORT: 7000
      TUNBUN_TOKEN: REPLACE_WITH_THE_SAME_SECRET_AS_SERVER
      TUNBUN_LOCAL_PORT_TO_FQDN: "8080:app1-abc123.b-cdn.net,8081:app2-abc123.b-cdn.net"
      TUNBUN_DASHBOARD_USER: admin
      TUNBUN_DASHBOARD_PASSWORD: changeme
```

Then run, for example:

```bash
docker compose up -d
docker compose logs -f tunbun-client
```

### Homelab notes

- `network_mode: host` is simplest on Linux homelab hosts.
- If your apps run on another machine, set `TUNBUN_LOCAL_IP` to that reachable LAN IP.
- On Docker Desktop (Mac/Windows), do not use host networking for this pattern; use published ports and `TUNBUN_LOCAL_IP=host.docker.internal`.

## 3) Verify traffic path

1. Confirm client is connected in logs (no auth/connection errors).
2. Hit your pull-zone URL.
3. If needed, test origin directly:

```bash
curl -sSI "http://<your-anycast-origin-ip>/" -H "Host: <your-zone>.b-cdn.net"
```

If response headers still indicate Bunny CDN, your origin is still pointing at Bunny instead of your Magic Container endpoint.

## Minimal environment reference

### Common

| Variable | Description |
|---|---|
| `TUNBUN_MODE` | `server` or `client` |
| `TUNBUN_TOKEN` | Shared secret (must match on both sides) |
| `TUNBUN_LOG_LEVEL` | frp log level (`info` default) |
| `TUNBUN_DASHBOARD_PORT` | `7500` | set `0` to disable dashboard |
| `TUNBUN_DASHBOARD_USER` | no | defaults to `admin` |
| `TUNBUN_DASHBOARD_PASSWORD` | no | defaults to `changeme` |

### Server

| Variable | Default | Description |
|---|---|---|
| `TUNBUN_BIND_PORT` | `7000` | frp control port |
| `TUNBUN_VHOST_HTTP_PORT` | `80` | incoming HTTP vhost port |

### Client

| Variable | Required | Description |
|---|---|---|
| `TUNBUN_SERVER_ADDR` | yes | Bunny Anycast IP/host for port `7000` |
| `TUNBUN_SERVER_PORT` | no | defaults to `7000` |
| `TUNBUN_LOCAL_PORT_TO_FQDN` | yes | `port:hostname,port:hostname` mappings |
| `TUNBUN_LOCAL_IP` | no | defaults to `127.0.0.1` |
| `TUNBUN_PROXY_TYPE` | no | `http` (default) or `https` |

## Optional: build/publish image

```bash
./build.sh
./build.sh --push
./build.sh --push --multiarch
```

## Links

- [Bunny.net Magic Containers docs](https://docs.bunny.net/magic-containers)
- [frp](https://github.com/fatedier/frp)
