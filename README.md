# Egress Monitor

Logs & collects network egress traffic.

## Why This Exists

TL;DR: Sometimes you just need to know what's phoning home from your Ubuntu box without installing enterprise monitoring stacks or wrestling with overengineered solutions.

### The Problem

You want basic egress monitoring on your Ubuntu servers. Simple question: "What's this machine talking to?"

### Why Not Existing Tools?

- **Enterprise solutions** (Datadog, New Relic, etc.) - Overkill for simple egress visibility. You're not monitoring a fleet of 500 servers, you just want to see outbound connections.
- **Wireshark/tcpdump** - Brilliant for deep packet inspection, terrible for "just show me what domains we're hitting." You wanted monitoring, not a part-time job analyzing pcaps.
- **Netflow/sFlow** - Requires collectors, analyzers, and infrastructure. You wanted a simple tool, not a research project.
- **Various commercial agents** - Half of them want to send your data to their cloud. The other half require MySQL, Redis, and a small server farm to run the dashboard.

### What This Does Instead

- Runs on the box you want to monitor
- Shows you egress connections in a way humans can read
- Doesn't require external infrastructure, databases, or cloud accounts
- Does one thing without bringing along 47 dependencies or requiring a PhD

### The Real Reason

It was a fun side project that took an afternoon instead of spending three days evaluating enterprise tools that do 100x more than needed or fighting with configuration files that assume you're running Kubernetes.

Sometimes the best tool is the one you actually finish and use.

## How It Works

See [DESIGN.md](./DESIGN.md) for the full technical design and rationale.

**TL;DR:**

- **Agent** logs DNS (via dnsmasq) and IP egress (via iptables)
- Cron jobs consolidate logs into two compact files (`unique-domains.log`, `unique-ips.log`)
- **Collector** fetches these files and analyzes for anomalies
- No packet captures, no databases, just smart log aggregation

## Requirements

### Agent dependencies

- `dnsmasq` (installed automatically if missing)
- `iptables` (for logging egress traffic)
- `journalctl` (for logging network activity)
- `cron` (for running the consolidation script)

### Collector dependencies

- `curl` (for RDAP lookups)
- `dig` (for reverse DNS lookups)
- `jq` (for parsing JSON)

## Usage

The repo comes with two use-cases:

- Agent: Runs on the box you want to monitor, minimal dependencies, lean & mean.
- Collector: Runs on a separate machine, consumes logs from the agent.

Currently the repo isn't built and released, so both modes require a git clone.

### Agent deployment (on the box you want to monitor)

- `git clone https://github.com/alexmorleyfinch/egress-monitor.git`
- `cd egress-monitor/`
- `git pull` - if you want to update
- `sudo ./src/agent/install.sh` - idempotent install script
- `sudo ./src/agent/uninstall.sh` - idempotent uninstall script

### Collector deployment (local machine)

- `git clone https://github.com/alexmorleyfinch/egress-monitor.git`
- `cd egress-monitor/`
- `git pull` - if you want to update

### Collecting logs from the agent (from the collector)

You need to have access to the Agent server via ssh, like `ssh alex@kai`

- `./src/collector/fetch.sh alex@kai` - use any ssh user+alias to a server running the agent

Helper scripts:

- `./src/collector/ptr_lookup.sh 11.22.33.44` - PTR response
- `./src/collector/rdap_lookup.sh 11.22.33.44` - raw RDAP response
- `./src/collector/rdap_lookup.sh 11.22.33.44 | ./src/collector/rdap_name.sh` - best guess at name
- `./src/collector/rdap_lookup.sh 11.22.33.44 | ./src/collector/rdap_readable.sh` - simplified RDAP json

## TODO

Agent:

- [Low] Installation via git clone is a pain, make a release
- [Med] Timestamps in domain logs are inconsistent with the IP logs

Collector:

- [Med] We need caching and more efficient enriching
- [Med] We need filtering and domain whitelist
