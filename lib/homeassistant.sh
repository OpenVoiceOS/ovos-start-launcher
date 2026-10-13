# Redeem private wizard input after sudo, never from a shareable recipe.
# Return 0 for a complete handoff, 1 only for an explicitly absent handoff,
# and 2 for every transport/validation failure. The caller cleans up on exit.
claim_homeassistant() {
  HOMEASSISTANT_URL=''
  HOMEASSISTANT_API_KEY=''
  [ -n "${ovos_track:-}" ] || return 1
  [ "${#ovos_track}" -eq 64 ] || return 2
  case "$ovos_track" in *[!0-9a-f]*) return 2;; esac
  ovos_ha_response=$(mktemp "${TMPDIR:-/tmp}/ovos-ha.XXXXXX") || return 2
  if ! ovos_ha_http=$(curl -q --config - --proto '=https' --connect-timeout 5 --max-time 20 --max-filesize 4098 --silent --output "$ovos_ha_response" --write-out '%{http_code}' <<OVOS_HA_REQUEST
url = "https://start-api.smartgic.io/v1/homeassistant"
request = "POST"
header = "Authorization: Bearer $ovos_track"
header = "Content-Type: application/json"
data = "{}"
OVOS_HA_REQUEST
  ); then return 2; fi
  case "$ovos_ha_http" in
    204)
      [ ! -s "$ovos_ha_response" ] || return 2
      rm -f "$ovos_ha_response" || return 2
      ovos_ha_response=''
      return 1;;
    200) :;;
    *) return 2;;
  esac
  ovos_ha_bytes=$(wc -c < "$ovos_ha_response") || return 2
  [ "$ovos_ha_bytes" -le 4098 ] || return 2
  exec 5< "$ovos_ha_response"
  IFS= read -r HOMEASSISTANT_URL <&5 || return 2
  IFS= read -r HOMEASSISTANT_API_KEY <&5 || return 2
  exec 5<&-
  rm -f "$ovos_ha_response" || return 2
  ovos_ha_response=''
  # Byte equality rejects extra lines, NULs discarded by shells and truncation.
  ovos_ha_expected=$(printf '%s\n%s\n' "$HOMEASSISTANT_URL" "$HOMEASSISTANT_API_KEY" | wc -c) || return 2
  [ "$ovos_ha_bytes" -eq "$ovos_ha_expected" ] || return 2
  [ "${#HOMEASSISTANT_URL}" -le 2048 ] || return 2
  case "$HOMEASSISTANT_URL" in *'?'*|*'#'*) return 2;; esac
  valid_url "$HOMEASSISTANT_URL" || return 2
  [ "${#HOMEASSISTANT_API_KEY}" -ge 20 ] && [ "${#HOMEASSISTANT_API_KEY}" -le 2048 ] || return 2
  case "$HOMEASSISTANT_API_KEY" in *[!A-Za-z0-9._~-]*) return 2;; esac
  return 0
}
