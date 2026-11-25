# Xray

This app dials out to an Xray server and offers this network's internet connection as an
exit for that server (Xray's VLESS reverse proxy). It opens no ports. Run it next to the
Tailscale app so the tunnel travels over your tailnet and never needs a public port.

## What arriving traffic can reach

Only the public internet, over IPv4. Blocked:

- every private and reserved range (home network, Home Assistant, the router, Tailscale's
  100.64.0.0/10, link-local, loopback), checked both on the requested address and on the
  address a name resolves to;
- all IPv6, because local devices can have public IPv6 addresses.

## Options

| Option | Meaning |
|---|---|
| `tunnel_address` | Tailscale machine name of the server, such as `vps-test`. Not an IP: the tunnel has no TLS of its own (Tailscale encrypts it) and Xray only allows that towards a private name. |
| `tunnel_dns` | DNS server for that name; keep `100.100.100.100` (Tailscale MagicDNS). |
| `tunnel_port` | Tunnel port on the server (Tailscale only). |
| `tunnel_uuid` | The tunnel ID held by the server. Keep it secret. |
| `log_level` | Xray error log level. Access logs are always off. |

## Tailscale app

The Tailscale app must not use userspace networking (set `userspace_networking: false`),
otherwise other apps cannot reach tailnet addresses.
