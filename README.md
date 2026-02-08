# Egress Monitor

Monitors the network Egress and DNS.

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

## Dependencies

- `dig` (for reverse DNS lookups)
- `curl` (for RDAP lookups)
- `jq` (for parsing JSON)

and:

- `git` (for deployment)

## Deployment

Maybe one day we'll make a tarball or something.

- `git clone https://github.com/alexmorleyfinch/egress-monitor.git`
- `egress-monitor/install.sh`


# Usage

TODO
