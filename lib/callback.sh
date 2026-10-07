# Minimal, optional progress reporting. The capability can only write status.
# Never accept a URL, message, log, credential or device identifier from input.
report_status() {
  [ -n "${ovos_track:-}" ] || return 0
  [ "${#ovos_track}" = 64 ] || return 0
  case "$ovos_track" in *[!0-9a-f]*) return 0;; esac
  case "$1" in started|downloading|installing|installed|services_ready|voice_ready|needs_attention|failed|cancelled) :;; *) return 0;; esac
  command -v curl >/dev/null 2>&1 || return 0
  # -q must be first: an inherited curlrc must not enable tracing or redirects.
  # Keep the bearer out of argv. Ignore every transport failure; installation
  # never depends on the browser or status relay being reachable.
  curl -q --config - --proto '=https' --connect-timeout 2 --max-time 3 --silent --fail --output /dev/null <<OVOS_STATUS >/dev/null 2>&1 || :
url = "https://ovos-install-status.goldyfruit.chatgpt.site/v1/events"
request = "POST"
header = "Authorization: Bearer $ovos_track"
header = "Content-Type: application/json"
data = "{\"event\":\"$1\"}"
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
