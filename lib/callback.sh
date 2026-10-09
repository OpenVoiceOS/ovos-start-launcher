# Minimal, optional progress reporting. Never accept arbitrary destinations,
# messages, logs, credentials or device identifiers from installer output.
valid_error_url() {
  case "$1" in https://paste.uoi.io/*) :;; *) return 1;; esac
  ovos_error_id=${1#https://paste.uoi.io/}
  ovos_error_id=${ovos_error_id%/}
  case "$ovos_error_id" in ''|*[!A-Za-z0-9_-]*) return 1;; esac
  [ "${#ovos_error_id}" -le 128 ]
}

report_status() {
  [ -n "${ovos_track:-}" ] || return 0
  [ "${#ovos_track}" = 64 ] || return 0
  case "$ovos_track" in *[!0-9a-f]*) return 0;; esac
  case "$1" in started|downloading|installing|installed|services_ready|voice_ready|needs_attention|failed|cancelled) :;; *) return 0;; esac
  ovos_error_field=''
  if [ "$1" = failed ] && valid_error_url "${2:-}"; then
    ovos_error_field=",\\\"errorUrl\\\":\\\"$2\\\""
  fi
  command -v curl >/dev/null 2>&1 || return 0
  # -q must be first: an inherited curlrc must not enable tracing or redirects.
  # Keep the bearer out of argv. Ignore every transport failure; installation
  # never depends on the browser or status relay being reachable.
  curl -q --config - --proto '=https' --connect-timeout 2 --max-time 3 --silent --fail --output /dev/null <<OVOS_STATUS >/dev/null 2>&1 || :
url = "https://start-api.smartgic.io/v1/events"
request = "POST"
header = "Authorization: Bearer $ovos_track"
header = "Content-Type: application/json"
data = "{\"event\":\"$1\"$ovos_error_field}"
OVOS_STATUS
}

load_status_token() {
  ovos_track=''
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-token"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    IFS= read -r ovos_track < "$ovos_status_path" || ovos_track=''
  fi
}

report_saved_install() {
  [ -n "${ovos_track:-}" ] || return 0
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-installed"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    ovos_status_receipt=''
    IFS= read -r ovos_status_receipt < "$ovos_status_path" || return 0
    [ "$ovos_status_receipt" = "$ovos_track" ] || return 0
    report_status installed
  fi
}
