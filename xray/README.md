# Xray

Runs [Xray](https://github.com/XTLS/Xray-core) as a reverse-tunnel bridge: it dials out
to your own server and lets that server use this network as an internet exit. Nothing
listens on this device, and nothing arriving through the tunnel can reach the local
network.
