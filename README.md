# Egress Monitor

Logs & collects network egress traffic.

## Why This Exists

TL;DR: Sometimes you just need to know what's phoning home from your Ubuntu box without installing enterprise monitoring stacks or wrestling with overengineered solutions.

### The Problem

You want basic egress monitoring on your Ubuntu servers. Simple question: "What's this machine talking to?"

### Why Not Existing Tools?

- __Enterprise solutions__ (Datadog, New Relic, etc.) - Overkill for simple egress visibility. You're not monitoring a fleet of 500 servers, you just want to see outbound connections.
- __Wireshark/tcpdump__ - Brilliant for deep packet inspection, terrible for "just show me what domains we're hitting." You wanted monitoring, not a part-time job analyzing pcaps.
- __Netflow/sFlow__ - Requires collectors, analyzers, and infrastructure. You wanted a simple tool, not a research project.
- __Various commercial agents__ - Half of them want to send your data to their cloud. The other half require MySQL, Redis, and a small server farm to run the dashboard.

### What This Does Instead

- Runs on the box you want to monitor
- Shows you egress connections in a way humans can read
- Doesn't require external infrastructure, databases, or cloud accounts
- Does one thing without bringing along 47 dependencies and a PhD

### The Real Reason

It was a fun side project that took an afternoon instead of spending three days evaluating enterprise tools that do 100x more than needed or fighting with configuration files that assume you're running Kubernetes.

Sometimes the best tool is the one you actually finish and use.

## Requirements

### Agent dependencies

- `dnsmasq` (for logging DNS queries)
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
- `./src/agent/install.sh` - idempotent install script
- `./src/agent/uninstall.sh` - idempotent uninstall script

### Collector deployment (local machine)

- `git clone https://github.com/alexmorleyfinch/egress-monitor.git`
- `cd egress-monitor/`
- `git pull` - if you want to update
- `./src/collector/install.sh` - idempotent install script (checks commands exist like `curl`, `dig`, `jq` etc)

### Collecting logs from the agent (from the collector)

> NOTE this needs improving
- `ssh user@my-box cat /var/log/egress-monitor/unique-ips.log`
- `ssh user@my-box cat /var/log/egress-monitor/unique-domains.log`

### Eventually... TODO

Pipe raw logs to the collector for analysis:

- `ssh user@my-box cat /var/log/egress-monitor/unique-ips.log | ./src/collector/unique-ips/status.sh` 
- `ssh user@my-box cat /var/log/egress-monitor/unique-domains.log | ./src/collector/unique-domains/status.sh`

Get identification information for a specific domain or IP:

- `./src/collector/identify.sh -d example.com`
- `./src/collector/identify.sh -i 11.22.33.44`

## TODO

- Maybe one day we'll make a tarball or something
