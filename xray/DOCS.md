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
| `tunnel_congestion` | `system` (kernel default, cubic) or `bbr`. See below. |
| `log_level` | Xray error log level. Access logs are always off. |

## Tunnel speed (`tunnel_congestion`)

Downloads through this exit are uploads from your home line, inside one long-lived TCP
connection with a long round trip. With the kernel default (cubic), the tunnel sends in
bursts; a home router with a small upload buffer drops the tail of each burst, and cubic
then slows down for many seconds. `bbr` paces packets at the measured line rate and
ignores isolated losses, which on such lines is usually two to three times faster.

`bbr` needs the app's `NET_ADMIN` permission (BBR is not on the kernel's unprivileged list
and is a module that only `NET_ADMIN` may load). It applies to the tunnel socket only.
If the kernel has no BBR, the tunnel still connects with the default; about 20 seconds
after start the log says either `Kernel has bbr; the tunnel uses it` or a warning that it
does not.

## Tailscale app

The Tailscale app must not use userspace networking (set `userspace_networking: false`),
otherwise other apps cannot reach tailnet addresses.
