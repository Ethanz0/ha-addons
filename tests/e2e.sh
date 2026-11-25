#!/usr/bin/env bash
# End-to-end test of the Xray app with Docker, no Home Assistant needed.
#
#   tester --socks--> portal (stands in for the server) <--tunnel-- bridge (this app)
#                                                                     |
#                                                     "lan" network: lanweb (a local device)
#
# Passes when the internet is reachable through the tunnel and the local device is not
# (by IP, by name, loopback, the Tailscale range, IPv6), while the bridge itself can
# reach the local device (so the blocks are real, not a broken network). The server name is
# resolved through Docker's DNS server (127.0.0.11), as on the Pi through Tailscale's.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
image=ha-xray-test
p=hax-$$
out="$here/out"
pass=0
fail=0

cleanup() {
	docker rm -f "$p-portal" "$p-bridge" "$p-lanweb" "$p-tester" >/dev/null 2>&1 || true
	docker network rm "$p-wan" "$p-lan" >/dev/null 2>&1 || true
	rm -rf "$out"
}
trap cleanup EXIT

check() { # name expect(ok|blocked) url
	local name=$1 expect=$2 url=$3 got
	if docker exec "$p-tester" curl -fsS -m 8 --socks5-hostname "$p-portal:1080" -o /dev/null "$url" 2>/dev/null; then
		got=ok
	else
		got=blocked
	fi
	if [[ $got == "$expect" ]]; then
		echo "PASS  $name ($got)"
		pass=$((pass + 1))
	else
		echo "FAIL  $name: expected $expect, got $got"
		fail=$((fail + 1))
	fi
}

docker build -q -t "$image" "$here/../xray" >/dev/null
mkdir -p "$out"
uuid=$(docker run --rm --entrypoint xray "$image" uuid)

cat >"$out/portal.json" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {"tag": "tunnel-in", "port": 10443, "protocol": "vless",
     "settings": {"decryption": "none", "clients": [{"id": "$uuid", "reverse": {"tag": "r-home"}}]}},
    {"tag": "client-in", "port": 1080, "protocol": "socks", "settings": {"udp": false}}
  ],
  "outbounds": [{"tag": "direct", "protocol": "freedom"}],
  "routing": {"rules": [{"inboundTag": ["client-in"], "outboundTag": "r-home"}]}
}
EOF
docker run --rm --entrypoint xray -v "$out:/c:ro" "$image" run -test -config /c/portal.json >/dev/null

docker network create "$p-wan" >/dev/null
docker network create "$p-lan" >/dev/null

docker run -d --name "$p-lanweb" --network "$p-lan" --entrypoint sh "$image" -c \
	'while true; do printf "HTTP/1.0 200 OK\r\nContent-Length: 3\r\n\r\nhi\n" | nc -l -p 8080; done' >/dev/null
lan_ip=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$p-lan\").IPAddress}}" "$p-lanweb")

docker run -d --name "$p-portal" --network "$p-wan" --entrypoint xray -v "$out:/c:ro" "$image" \
	run -config /c/portal.json >/dev/null

jq -n --arg a "$p-portal" --arg u "$uuid" \
	'{tunnel_address: $a, tunnel_dns: "127.0.0.11", tunnel_port: 10443, tunnel_uuid: $u, log_level: "warning"}' >"$out/options.json"
docker create --name "$p-bridge" --network "$p-wan" -v "$out/options.json:/data/options.json:ro" "$image" >/dev/null
docker network connect "$p-lan" "$p-bridge"
docker start "$p-bridge" >/dev/null

docker run -d --name "$p-tester" --network "$p-wan" --entrypoint sleep "$image" 300 >/dev/null
sleep 3

if docker exec "$p-bridge" curl -fsS -m 5 -o /dev/null "http://$p-lanweb:8080/hostname"; then
	echo "PASS  control: the bridge itself reaches the local device"
	pass=$((pass + 1))
else
	echo "FAIL  control: the bridge cannot reach the local device; test network broken"
	fail=$((fail + 1))
fi

check "internet by name" ok "https://www.cloudflare.com/cdn-cgi/trace"
check "internet by IP" ok "http://1.1.1.1/cdn-cgi/trace"
check "local device by IP" blocked "http://$lan_ip:8080/hostname"
check "local device by name" blocked "http://$p-lanweb:8080/hostname"
check "loopback" blocked "http://127.0.0.1:8080/"
check "localhost name" blocked "http://localhost:8080/"
check "Tailscale range" blocked "http://100.100.100.100/"
check "IPv6 literal" blocked "http://[2606:4700:4700::1111]/"
check "home router style address" blocked "http://192.168.0.1/"

# tunnel_congestion: only the tunnel socket gets the setting, and Xray accepts the result.
# (Docker Desktop's kernel has no BBR, so this checks the rendered config, not the socket.)
render_n=0
render_check() { # name options-filter jq-assertion
	# A fresh file name per check: Docker Desktop's file sharing can serve a stale copy of a
	# file rewritten moments earlier.
	local name=$1 n=$((++render_n))
	jq "$2" "$out/options.json" >"$out/options-r$n.json"
	if docker run --rm --entrypoint xray-render -v "$out:/c:ro" "$image" "/c/options-r$n.json" >"$out/rendered-r$n.json" &&
		jq -e "$3" "$out/rendered-r$n.json" >/dev/null &&
		docker run --rm --entrypoint xray -v "$out:/c:ro" "$image" run -test -config "/c/rendered-r$n.json" >/dev/null; then
		echo "PASS  $name"
		pass=$((pass + 1))
	else
		echo "FAIL  $name"
		fail=$((fail + 1))
	fi
}
render_check "congestion default: no tcpCongestion" '.' \
	'[.outbounds[] | .streamSettings.sockopt.tcpCongestion // empty] == []'
render_check "congestion bbr: tunnel socket only" '.tunnel_congestion = "bbr"' \
	'[.outbounds[] | {tag, cc: .streamSettings.sockopt.tcpCongestion} | select(.cc)] == [{tag: "tunnel", cc: "bbr"}]'

echo "--- bridge log"
docker logs "$p-bridge" 2>&1 | tail -n 15
echo "--- $pass passed, $fail failed"
[[ $fail -eq 0 ]]
