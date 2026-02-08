# Egress Monitor - Technical Design

## Problem Statement

We want to monitor outgoing network connections without drowning in data. We need to know **where** we're reaching, **when**, and **how often** - not capture every byte.

## Design Decisions

### Why Monitor DNS?

Monitoring DNS queries reveals most egress domains. Yes, this misses:
- DoH/DoT (DNS over HTTPS/TLS)
- Direct IP connections
- Custom DNS resolvers

**But** - these are exactly the anomalies we want to detect! Normal servers use the system resolver. Anything else is suspicious.

### Why Monitor IP Egress Too?

Catches direct IP connections that bypass DNS entirely. Combined with DNS monitoring, gives complete egress visibility.

## Implementation

__Minimal spec__: Efficiently monitor internal DNS and IP egress.

## How it should work

- We dont want to lose information, and we don't want logs exploding is size, so we must _aggregate_ logs into a smaller set of files.
- We use CRON jobs to scrape unread logs and append stats to our aggregate files.

### Monitor DNS Egress

We can't get good logs from the system resolver, so we use `dnsmasq` to log DNS requests:

- Use logrotate to stop dnsmasq logs getting out of hand.
- We replace the systemd-resolved service config to point to dnsmasq, which points to the same upstream DNS servers.

#### Unique domains file

> /var/log/egress-monitor/unique-domains.log

```
[domain] [count] [timestamp] [...comma_separated_IPs]
```

### Monitor IP Egress

We can get `iptables` to log egress to journalctl:

- `journalcrl` already manages log rotation

#### Unique IPs file

> /var/log/egress-monitor/unique-ips.log

```
[ip] [count] [timestamp]
```

So we have two systems relying on logging, with log rotation handles, generating 2 files:

- `unique-domains.log` - A list of domains we've seen and how many times we've reached them.
- `unique-ips.log` - A list of IP's we've seen and how many times we've reached them.

These files are constantly updated. We don't want to grep the logs from scratch each time. We store a cursor and read only the new lines from dnsmasq and journalctl. These two files are the jackpot.


### Poll these logs from collectors and analyze them

The analysis of these files shouldn't happen on server. The server just needs to collect the data. Some other process will pull and analyze the data.

TODO write about this.

## Trade-offs

**What we gain:**
- Minimal server footprint
- Human-readable logs
- No external dependencies

**What we accept:**
- Won't catch sophisticated attackers using encrypted DNS tunnels
- That's fine - this catches 95% of cases and flags the other 5% as suspicious

This is a simple tool to monitor egress. It's not a security tool. It's not a monitoring tool. It's a simple tool to monitor egress.
