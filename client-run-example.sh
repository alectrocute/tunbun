sudo docker run --rm --network host \
  -e TUNBUN_MODE=client \
  -e TUNBUN_SERVER_ADDR=109.224.229.216 \
  -e TUNBUN_SERVER_PORT=7000 \
  -e TUNBUN_TOKEN=my-secret-token \
  -e TUNBUN_LOCAL_PORT_TO_FQDN=4002:alectrocute-example-app.b-cdn.net \
  -e TUNBUN_DASHBOARD_USER=admin \
  -e TUNBUN_DASHBOARD_PASSWORD=admin \
  -v ./frpc_store.json:/frpc_store.json \
  alectrocute/tunbun:latest
  