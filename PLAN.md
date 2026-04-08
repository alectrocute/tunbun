# tunbun

Tunbun is a Cloudflare Tunnel alternative that runs natively on bunny.net's Magic Container service. It lets people easily spin up a tunnel to their local network, and access it from the internet with TLS encryption, regardless of NAT or firewall rules.

Link to docs: https://docs.bunny.net/magic-containers

Link to frp docs: https://github.com/fatedier/frp

## Master Plan

- In this repo, we'll be creating a Docker image that we publish to a public registry. This Docker image, via env vars in a `docker-compose.yml`, for example, can be operated as a server (inside a Magic Container) or as a client (outside a Magic Container/on a user's local machine, e.g. Plex server). It will use `frp` as its main dependency.

- When the Magic Container starts up, it will print out useful details about the container, such as its IP address, the port it's listening on, and the URL of the web interface—everything the user needs to configure the client.

- Nowhere should config files (e.g. `tunbun.conf`, `config.yaml`, `frpc.toml`, etc.) be stored or used. Keep everything in memory, env vars, etc.

- The client should use an env var that lets you map a local port to a FQDN, like `TUNBUN_LOCAL_PORT_TO_FQDN=8080:example1-abc123.bunny.run,8081:example2-abc123.bunny.run`.
