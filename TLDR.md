# TLDR

The server is already consolidating logs every 5mins.

Every now and then you have read the report:
```
# pull repo if needed
cd ~/egress-monitor

# pass any ssh user+alias you want
./src/collector/fetch.sh alex@kai
```

E.G:

```
IP_ADDRESS           COUNT  TIMESTAMP                 DOMAIN               PTR
---------------------------------------------------------------------------------------------------------------------
67.207.67.3          2212   2026-02-08T21:30:00+00:00                      [no_ptr]
149.154.166.110      1750   2026-02-08T21:29:56+00:00 api.telegram.org     [no_ptr]
192.168.1.109        162    2026-02-08T21:00:02+00:00                      Alexs-MBP.broadband.
68.183.90.120        26     2026-02-08T20:59:23+00:00                      derp6-blr.tailscale.com.
49.13.204.141        26     2026-02-08T20:59:23+00:00                      static.141.204.13.49.clients.your-server.de.
45.159.98.145        26     2026-02-08T20:59:23+00:00                      derp22d.tailscale.com.
```

It takes a while to run because RDAP 429 us
