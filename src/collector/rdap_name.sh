#!/usr/bin/env bash
# rdap_name.sh
#
# Resolves the "name" from an RDAP IP response using the same fallback logic:
#   1. rdap.name (unless it's a bare IP or IP range)
#   2. first handle found recursively in entities
#   3. port43
#
# Usage:
#   curl -sL https://rdap.org/ip/8.8.8.8 | ./rdap_name.sh

set -euo pipefail

jq -r '
# Recursively find the first entity handle (depth-first)
def firstHandle:
  if type != "array" then null
  else
    reduce .[] as $ent (null;
      if . != null then .
      elif $ent.handle then $ent.handle
      elif $ent.entities then ($ent.entities | firstHandle)
      else null
      end
    )
  end;

# Nullify name if it looks like a bare IP or IP range
(.name // "" |
  if test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
  elif test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3} - [0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
  elif . == "" then null
  else .
  end
) // ((.entities // []) | firstHandle) // .port43
'