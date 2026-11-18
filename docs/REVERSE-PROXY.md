# Reverse proxy

The web server listens on `8080` inside the container. Publish it only where
your proxy can reach it:

- **Proxy on the same host:** `BIND_IP=127.0.0.1`
- **Proxy on another host** (e.g. a public nginx that reaches this machine over
  Tailscale or a LAN): `BIND_IP=<tailscale-or-lan-address>`
- **All interfaces:** `BIND_IP=0.0.0.0` (default) — make sure a firewall or
  Tailscale ACL limits access.

## nginx

WebSockets are used for `/text`, `/audio`, `/chat`, `/data_plugins` and
`/data_plugins/metricsmonitor`. Proxying `/` with the upgrade headers covers all
of them.

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 443 ssl;
    http2 on;
    server_name tuner.example.com;

    ssl_certificate     /etc/letsencrypt/live/tuner.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tuner.example.com/privkey.pem;

    location / {
        proxy_pass http://100.x.y.z:8080;
        proxy_http_version 1.1;

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        # Overwrite client-supplied X-Forwarded-For: appending it lets clients spoof IPs.
        proxy_set_header X-Forwarded-For   $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        $connection_upgrade;

        # Long-lived WebSockets (audio, spectrum, plugins)
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
        proxy_cache off;
    }
}
```

`X-Real-IP` is authoritative for client location, connection logs and bans.
Overwrite any client-supplied `X-Forwarded-For` with `$remote_addr`; do not use
`$proxy_add_x_forwarded_for`, because a client can prepend a forged value. Only
trusted proxies may reach port 8080. If another proxy (e.g. Cloudflare) is in
front, configure `ngx_http_realip_module` so `$remote_addr` is the real client
before setting these headers.

## Caddy

```caddyfile
tuner.example.com {
    reverse_proxy 100.x.y.z:8080
}
```

Caddy handles WebSocket upgrades and timeouts automatically.

## Cloudflare

- Enable WebSockets for the zone (on by default for proxied records).
- The app sends periodic pings, which keeps the connection below Cloudflare's
  idle timeout; keep `proxy_read_timeout` on the origin above it.
- Do not cache `/` or the WebSocket paths.
- If you use Cloudflare Tunnel instead of a public origin, point the tunnel at
  `http://<host>:8080`.

## Tailscale

When the proxy is on another machine in the tailnet, bind the container to the
Tailscale address (`tailscale ip -4`) or `0.0.0.0` and restrict with Tailscale
ACLs / the host firewall. Do not expose `8080` to the public internet without a
proxy and TLS.
