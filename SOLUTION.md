# Egress Monitor Solution

## What it should do

We want to monitor outgoing network connections. We can't log the entire request/response because that gets too big, too fast.

We just want to know __where__ we're reaching, and __when__ and __how often__.

When monitoring outgoing connections, we can monitor DNS requests to get the "domains" we're reaching, however:

- This doesn't catch egress that doesn't go through our DNS resolver (127.0.0.1:53)
- This doesn't catch egress that uses IP's directly.

So why bother?

Well, the __entire purpose__ is to know when "weird stuff" is happening. Most normal server usage reaches out to a few domains using the system resolver.

That means, any egress that reaches to unexpected domains, or IP's directly is weird. To avoid reaching out to IP's directly, attackers can perform DNS in many ways, like DoH, DoT, etc. We can't really stop this, so our only defence is to monitor the domains they do reach out to. If we see application code reaching out to obvious DNS servers like 1.1.1.1 or 8.8.8.8, we know that's weird, but also, it's easy to bypass this. An attacker could proxy DNS through another hardcoded IP etc.

Despite all this complexity and all the attacker workarounds, at the end of the day, we can monitor system DNS and IP egress to detect "weird behaviour", just by monitoring internal DNS and IP egress.

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

Two sides:

- Code that runs on the server, constantly populating the two files
- Code that runs on another host, periodically fetching the two files, analyzing them and alerting if something is wrong.

```
# Executable (have shebang, meant to be run):
consolidate.sh      ✓
install.sh          ✓
uninstall.sh        ✓

# Not executable (sourced, not run):
cursor.sh           ✗ (sourced by consolidate.sh)
setup.sh            ✗ (sourced by install.sh)
```

