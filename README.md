# tunbun

**tunbun** packages [frp](https://github.com/fatedier/frp) in a small Docker image you can run in two roles:

- **Server** (`frps`) — typically on [bunny.net Magic Containers](https://docs.bunny.net/magic-containers) or any host with a public hostname and open ports.
- **Client** (`frpc`) — on your home network or laptop, pointing at services you want on the internet (for example a local web app on port 8080).

Everything is driven by **environment variables**. There are no checked-in config files; the container only writes a short-lived TOML file under `/tmp` at startup.

Traffic is exposed as **HTTP or HTTPS virtual hosts** (hostname → local port). That fits websites and APIs well; arbitrary raw TCP (for example some game or database protocols) is not what `TUNBUN_LOCAL_PORT_TO_FQDN` is for.

---

## Get started in a few minutes

### 1. Get the image

**If you use a published Hub image** (example maintainer tag):

```bash
docker pull alectrocute/tunbun:latest
```

**Or build from this repo:**

```bash
docker build -t tunbun:latest .
# or: ./build.sh
```

### 2. Run the server

The server listens for frp clients and for HTTP(S) requests on the vhost ports you configure.

Minimal example (local testing):

```bash
docker run --rm -p 7000:7000 -p 80:80 -p 443:443 -p 7500:7500 \
  -e TUNBUN_MODE=server \
  -e TUNBUN_TOKEN=my-secret-token \
  tunbun:latest
```

On startup the container prints a short banner with ports, in-container IPs, and example client settings. For production, point DNS for your public hostnames at bunny (or your host) and map those hostnames to the container’s HTTP/HTTPS ports as your platform requires.

Set **`TUNBUN_DASHBOARD_PORT=0`** if you do not want the frps web dashboard.

### 3. Run the client

On the machine that runs the app (same host as the service, or reachable via `TUNBUN_LOCAL_IP`):

```bash
docker run --rm --network host \
  -e TUNBUN_MODE=client \
  -e TUNBUN_SERVER_ADDR=your-server.bunny.run \
  -e TUNBUN_SERVER_PORT=7000 \
  -e TUNBUN_TOKEN=my-secret-token \
  -e TUNBUN_LOCAL_PORT_TO_FQDN=8080:app-abc123.bunny.run \
  tunbun:latest
```

- **`TUNBUN_LOCAL_PORT_TO_FQDN`** — comma-separated list of `localPort:hostname` (example: `8080:app.bunny.run,3000:api.bunny.run`).
- **`TUNBUN_PROXY_TYPE`** — `http` (default) or `https` for backends that speak TLS locally.

**Docker Desktop (Mac / Windows):** host networking behaves differently. Prefer `TUNBUN_LOCAL_IP=host.docker.internal` and published ports instead of `--network host`.

### 4. Try with Compose

```bash
# Terminal A — server
docker compose --profile server up

# Terminal B — client (edit env in docker-compose.yml first)
docker compose --profile client up
```

---

## Environment reference

### Common

| Variable | Description |
|----------|-------------|
| `TUNBUN_MODE` | `server` (default) or `client`. |
| `TUNBUN_TOKEN` | Shared secret for frp auth. Strongly recommended; must match on server and client. |
| `TUNBUN_LOG_LEVEL` | frp log level (default `info`). |
| `TUNBUN_RUNTIME_CONF` | Path for ephemeral TOML (default `/tmp/tunbun-frp.toml`). |

### Server (`TUNBUN_MODE=server`)

| Variable | Default | Description |
|----------|---------|-------------|
| `TUNBUN_BIND_PORT` | `7000` | frp control port (`TUNBUN_SERVER_PORT` on the client). |
| `TUNBUN_VHOST_HTTP_PORT` | `80` | HTTP vhost port frps listens on. |
| `TUNBUN_VHOST_HTTPS_PORT` | `443` | HTTPS vhost port. |
| `TUNBUN_DASHBOARD_PORT` | `7500` | frps dashboard; set to `0` to disable. |
| `TUNBUN_DASHBOARD_USER` | `admin` | Dashboard login. |
| `TUNBUN_DASHBOARD_PASSWORD` | `admin` | Dashboard password — change for production. |

### Client (`TUNBUN_MODE=client`)

| Variable | Required | Description |
|----------|----------|-------------|
| `TUNBUN_SERVER_ADDR` | yes | Hostname or IP of the server (often your Magic Container hostname). |
| `TUNBUN_SERVER_PORT` | no (`7000`) | frp control port. |
| `TUNBUN_LOCAL_PORT_TO_FQDN` | yes | `port:host,...` mappings (see above). |
| `TUNBUN_LOCAL_IP` | `127.0.0.1` | Where the client reaches your service. |
| `TUNBUN_PROXY_TYPE` | `http` | `http` or `https` local backend. |
| `TUNBUN_FRPC_TLS_ENABLE` | `true` | Set to `false` only if your server uses legacy non-TLS frp. |

---

## Publishing your own image

From the repo, after `docker login`:

```bash
./build.sh --push
# multi-arch (amd64 + arm64) for Magic Container–style hosts:
./build.sh --push --multiarch
```

Optional version tag: `VERSION=0.1.0 ./build.sh --push`.

---

## Links

- [bunny.net Magic Containers](https://docs.bunny.net/magic-containers)
- [frp](https://github.com/fatedier/frp)
