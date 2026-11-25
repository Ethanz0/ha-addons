# Changelog

## 26.10.31-2

- The server is given by its Tailscale machine name and resolved through Tailscale DNS
  (Xray refuses an unencrypted tunnel to a 100.x address).
- Xray's own lookups of the server name get an exit (UDP 53 to tunnel_dns only);
  everything else unmatched is still blocked.

## 26.10.31-1

- First release: Xray 26.10.31 as a reverse-tunnel bridge with local network blocking.
