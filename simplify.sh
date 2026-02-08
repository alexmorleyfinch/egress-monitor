#!/usr/bin/env bash
# rdap_simplify.sh
#
# Simplifies an RDAP IP response JSON into a cleaner structure.
# Port of the TypeScript simplifyRdapResponse / simplifyEntity / simplifyRemark / formatVcard.
#
# Dependencies: jq (>= 1.6), bash (>= 4.x)
#
# Usage:
#   echo '{"objectClassName":"ip network", ...}' | ./rdap_simplify.sh [keep_roles] [hide_roles]
#
#   keep_roles: comma-separated roles to keep even if all roles are hidden (default: "registrant")
#   hide_roles: comma-separated roles to filter out from display (default: "noc")
#
# Output: JSON object with type "success" and simplified data, or type "error".
#
# Notes:
#   - No Zod schema validation is performed; we trust the shape and let jq handle missing fields.
#   - All semantic behavior from the TypeScript is preserved exactly:
#     * notices/remarks arrays are only included when non-empty
#     * entities are recursively simplified with the same role keep/hide logic
#     * vcard formatting handles adr (label preferred), email (pref-flagged first), tel (type suffixed keys),
#       and generic keys (duplicates merged with " | ")
#     * "version"/"4.0" entries in vcards are skipped
#     * remarks titled "Whois Inaccuracy Reporting" or "Terms and Conditions" are dropped
#     * name falls back to firstHandle(entities) then port43
#     * parent is true when parentHandle is absent/null

set -euo pipefail

KEEP_ROLES="${1:-registrant}"
HIDE_ROLES="${2:-noc}"

# Read all of stdin
INPUT=$(cat)

# ─────────────────────────────────────────────────────────────
# We build the entire transformation in one big jq program so
# we stay in JSON-land and avoid lossy bash string manipulation.
# ─────────────────────────────────────────────────────────────

jq -r --arg keep_roles "$KEEP_ROLES" --arg hide_roles "$HIDE_ROLES" '

# ── helpers ──────────────────────────────────────────────────

# Split a comma-separated string into an array
def csv_to_arr: split(",") | map(select(length > 0));

# ── simplifyRemark ───────────────────────────────────────────
# Returns a string or null.
# Drops remarks titled "Whois Inaccuracy Reporting" or "Terms and Conditions".
# Format: "[type]: title - description_lines\n... [link1, link2]"
def simplifyRemark:
  if .title == "Whois Inaccuracy Reporting" or .title == "Terms and Conditions" then
    null
  else
    (
      # Build prefix
      (if .type then "[\(.type)]: " else "" end) +
      (if .title then "\(.title) - " else "" end) +
      # Filter description lines: drop lines that are all dashes, drop empty/false
      ((.description // [])
        | map(select(. != null and . != false and . != "" and (test("^-+$") | not)))
        | join("\n")
      ) +
      # Append links if present
      (if .links and (.links | length) > 0 then
        " [" + ([.links[].href] | join(", ")) + "]"
       else
        ""
       end)
    )
  end;

# ── formatVcard ──────────────────────────────────────────────
# Input: the raw vcards array (array of [key, props, type, value] tuples).
# Output: a JSON object with merged keys.
#
# Behavior per key:
#   "version" with value "4.0" → skip
#   "adr"   → use props.label if present, else join(value). Dupes merged with " | ".
#   "email" → if props.pref exists, stash into a separate pref list (with numeric pref).
#             Otherwise collect into a list. Final: pref-sorted emails first, then non-pref, joined " | ".
#   "tel"   → if type is non-null/non-empty, key becomes "tel_<type>". Dupes merged with ", ".
#   other   → dupes merged with " | ".
#
# We process sequentially via reduce, carrying {obj, emailPrefs, emails} as state.
def formatVcard:
  # State: { obj: {}, emailPrefs: [[email, pref_num], ...], emails: [str, ...] }
  reduce .[] as $entry (
    { obj: {}, emailPrefs: [], emails: [] };

    $entry[0] as $key |
    $entry[1] as $props |
    $entry[2] as $type |
    $entry[3] as $value |

    # Compute string value: if array join(""), else tostring
    ($value | if type == "array" then map(tostring) | join("") else tostring end) as $strValue |

    if $key == "version" and ($value == "4.0" or $value == 4) then
      # Skip version 4.0
      .
    elif $key == "adr" then
      # Use props.label if present, otherwise strValue
      (if $props.label then $props.label else $strValue end) as $adrVal |
      .obj[$key] as $prev |
      .obj[$key] = (if $prev then "\($prev) | \($adrVal)" else $adrVal end)
    elif $key == "email" then
      if $props.pref then
        # Stash pref emails separately with their pref number for sorting
        .emailPrefs += [[$strValue, ($props.pref | tonumber)]]
      else
        # Accumulate non-pref emails in order
        .emails += [$strValue]
      end
    elif $key == "tel" then
      # Key becomes tel_<type> if type is a non-empty string
      (if $type and ($type | type) == "string" and ($type | length) > 0 then
        "\($key)_\($type)"
       else
        $key
       end) as $newKey |
      .obj[$newKey] as $prev |
      .obj[$newKey] = (if $prev then "\($prev), \($strValue)" else $strValue end)
    else
      # Generic: merge with " | "
      .obj[$key] as $prev |
      .obj[$key] = (if $prev then "\($prev) | \($strValue)" else $strValue end)
    end
  )
  # Post-process: merge pref emails (sorted by pref ascending) then non-pref emails
  | (
      (.emailPrefs | sort_by(.[1]) | map(.[0])) as $prefEmails |
      .emails as $nonPrefEmails |
      if ($prefEmails | length) > 0 or ($nonPrefEmails | length) > 0 then
        .obj.email = ($prefEmails + $nonPrefEmails | join(" | "))
      else
        .
      end
    )
  | .obj;

# ── firstHandle ──────────────────────────────────────────────
# Recursively find the first entity (depth-first) that has a handle.
def firstHandle:
  if type != "array" then null
  else
    reduce .[] as $ent (null;
      if . != null then .  # already found
      elif $ent.handle then $ent.handle
      elif $ent.entities then ($ent.entities | firstHandle)
      else null
      end
    )
  end;

# ── simplifyEntity ───────────────────────────────────────────
# Recursively simplifies an entity. Returns object or null.
def simplifyEntity(keepRoles; hideRoles):
  . as $ent |

  # Parse vcardArray: [type, vcardsRaw]
  (if .vcardArray and (.vcardArray | length) >= 2 and .vcardArray[0] == "vcard" then
    .vcardArray[1] | formatVcard
   else
    {}
   end) as $vcards |

  # Check if any of the entity roles are in keepRoles
  (any(.roles[]; . as $r | keepRoles | any(. == $r))) as $shouldKeep |

  # Filter roles: remove those in hideRoles
  ([.roles[] | select(. as $r | hideRoles | all(. != $r))]) as $filteredRoles |

  if ($filteredRoles | length) == 0 and ($shouldKeep | not) then
    null
  else
    # Recursively simplify sub-entities
    ([(.entities // [])[] | simplifyEntity(keepRoles; hideRoles)] | map(select(. != null))) as $ents |
    # Simplify remarks
    ([(.remarks // [])[] | simplifyRemark] | map(select(. != null))) as $rems |
    # Extract link hrefs
    ([(.links // [])[] | .href]) as $links |

    # Build result object
    ({
      handle: .handle,
      port43: .port43,
      roles: ($filteredRoles | join(",")),
      status: (if .status and (.status | length) > 0 then .status | join(",") else null end),
      vcard: $vcards
    }) +
    (if ($ents | length) > 0 then { entities: $ents } else {} end) +
    (if ($rems | length) > 0 then { remarks: $rems } else {} end) +
    (if ($links | length) > 0 then { links: ($links | join(", ")) } else {} end)
  end;

# ── main: simplifyRdapResponse ───────────────────────────────

($keep_roles | csv_to_arr) as $keepArr |
($hide_roles | csv_to_arr) as $hideArr |

# Compute notices and remarks (arrays of strings, nulls filtered)
([(.notices // [])[] | simplifyRemark] | map(select(. != null))) as $notices |
([(.remarks // [])[] | simplifyRemark] | map(select(. != null))) as $remarks |

# Determine name:
#   If rdap.name matches a bare IP or IP range, treat as if no name.
#   Fallback chain: name → firstHandle(entities) → port43
(
  (.name // "") |
  if test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
  elif test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3} - [0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
  elif . == "" then null
  else .
  end
) as $nameFromRdap |

((.entities // []) | firstHandle) as $handleFallback |

($nameFromRdap // $handleFallback // .port43) as $name |

# parent is true when parentHandle is absent/null
(if .parentHandle then false else true end) as $parent |

# Build simplified entities
([(.entities // [])[] | simplifyEntity($keepArr; $hideArr)] | map(select(. != null))) as $ents |

# Build the base result
({
  name: $name,
  handle: .handle,
  port43: (.port43 // null),
  parent: $parent,
  status: (if .status and (.status | length) > 0 then .status | join(",") else null end),
  type: (.type // null),
  entities: $ents
}) +
# Only append notices/remarks if non-empty (matching the TS behavior)
(if ($notices | length) > 0 then { notices: $notices } else {} end) +
(if ($remarks | length) > 0 then { remarks: $remarks } else {} end) |

# Wrap in success envelope
{ type: "success", data: . }

' <<< "$INPUT"