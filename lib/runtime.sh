# Shared, embedded terminal helpers. No fetched or user-supplied shell is sourced.
cancel_input() { say cancelled >&2; exit 130; }
restore_tty() { [ -z "${ovos_tty:-}" ] || stty "$ovos_tty" < /dev/tty; }

# Validate syntax locally; never send a token to a URL just to validate input.
valid_url() {
  case "$1" in http://?*|https://?*) :;; *) return 1;; esac
  case "$1" in *[[:space:][:cntrl:]]*|*'@'*|*'#'*|*'\'*) return 1;; esac
  ovos_host=${1#*://}; ovos_host=${ovos_host%%[/?]*}
  case "$ovos_host" in
    '['*']'*)
      ovos_address=${ovos_host#\[}; ovos_address=${ovos_address%%\]*}
      case "$ovos_address" in *:*) :;; *) return 1;; esac
      case "$ovos_address" in ''|*[!0-9a-fA-F:.]*) return 1;; esac
      ovos_port=${ovos_host#*\]}
      case "$ovos_port" in '') return 0;; :*) ovos_port=${ovos_port#:};; *) return 1;; esac;;
    *)
      ovos_address=${ovos_host%%:*}
      case "$ovos_address" in ''|.*|*.|*[!a-zA-Z0-9._-]*) return 1;; esac
      case "$ovos_host" in *:*) ovos_port=${ovos_host#*:};; *) return 0;; esac;;
  esac
  case "$ovos_port" in ''|*[!0-9]*|??????*) return 1;; esac
  # Strip leading zeros before arithmetic, avoiding shell octal interpretation.
  while [ "${ovos_port#0}" != "$ovos_port" ]; do ovos_port=${ovos_port#0}; done
  [ -n "$ovos_port" ] && [ "$ovos_port" -le 65535 ]
}

read_field() {
  # Fixed trusted prompt key and validation kind; answer is never evaluated.
  if [ "$2" = secret ]; then
    ovos_tty=$(stty -g < /dev/tty)
    stty -echo < /dev/tty
  fi
  while :; do
    message "$1" > /dev/tty
    ovos_read_ok=true
    IFS= read -r ovos_answer < /dev/tty || ovos_read_ok=false
    if [ "$2" = secret ]; then
      printf '\n' > /dev/tty
    fi
    [ "$ovos_read_ok" = true ] || cancel_input
    [ "$ovos_answer" != :cancel ] || cancel_input
    case "$ovos_answer" in ''|*[![:space:]]*) :;; *) ovos_answer='';; esac
    if [ -z "$ovos_answer" ]; then say required > /dev/tty; continue; fi
    if [ "$2" = url ] && ! valid_url "$ovos_answer"; then say urlError > /dev/tty; continue; fi
    if [ "$2" = secret ]; then restore_tty; ovos_tty=''; fi
    return 0
  done
}

terminal_choice() {
  message "$1" > /dev/tty
  ovos_answer=''
  IFS= read -r ovos_answer < /dev/tty || return 1
  [ "$ovos_answer" != :cancel ]
}

check_services() {
  ovos_services='ovos-messagebus ovos-core'
  if [ "$ovos_experience" = hub ]; then
    ovos_services="$ovos_services hivemind-listener"
  else
    ovos_services="$ovos_services ovos-audio ovos-listener"
  fi
  ovos_health=unknown
  if [ "$ovos_method" = containers ]; then
    # Compose service names come from installed OVOS Docker; do not infer health
    # from unrelated running containers or launch a privileged Docker command.
    if command -v docker >/dev/null 2>&1 && ovos_running=$(docker ps --filter label=com.docker.compose.project=ovos --format '{{.Label "com.docker.compose.service"}}' 2>/dev/null); then
      ovos_health=running
      for ovos_service in $ovos_services; do
        ovos_compose_service=$(printf '%s' "$ovos_service" | tr '-' '_')
        printf '%s\n' "$ovos_running" | grep -Fx "$ovos_compose_service" >/dev/null || ovos_health=waiting
      done
    fi
  elif [ "$ovos_device" = mac ]; then
    if command -v launchctl >/dev/null 2>&1; then
      ovos_health=running
      for ovos_service in $ovos_services; do
        ovos_label="com.openvoiceos.$ovos_service"
        [ "$ovos_service" != ovos-core ] || ovos_label=com.ovos.service
        if ! launchctl print "gui/$(id -u)/$ovos_label" 2>/dev/null | grep -q 'state = running'; then ovos_health=waiting; fi
      done
    fi
  elif command -v systemctl >/dev/null 2>&1; then
    ovos_health=running
    for ovos_service in $ovos_services; do
      if ! systemctl --user is-active --quiet "$ovos_service.service" 2>/dev/null && ! systemctl is-active --quiet "$ovos_service.service" 2>/dev/null; then ovos_health=waiting; fi
    done
  fi
  case "$ovos_health" in running) say servicesOk;; waiting) say servicesMissing;; *) say servicesUnknown;; esac
}

sound_check() {
  # The installed virtualenv has the real OVOS configuration and MessageBus API.
  # Limit connection/event waits; a queued utterance never counts as audible.
  if [ "$ovos_method" = containers ]; then
    command -v docker >/dev/null 2>&1 || return 1
  else
    ovos_python="$HOME/.venvs/ovos/bin/python3"
    [ -x "$ovos_python" ] || ovos_python="$HOME/.venvs/ovos/bin/python"
    [ -x "$ovos_python" ] || return 1
  fi
  run_sound_python() {
    if [ "$ovos_method" = containers ]; then docker exec -i ovos_audio python3 "$@";
    else "$ovos_python" "$@"; fi
  }
  run_sound_python - "$ovos_locale" "$(message audioTest)" <<'OVOS_SOUND'
import sys
import threading
import signal
signal.alarm(30)
try:
    from ovos_bus_client import MessageBusClient, Message
    client = MessageBusClient()
    ended = threading.Event()
    client.on("recognizer_loop:audio_output_end", lambda _: ended.set())
    client.run_in_thread()
    if not client.connected_event.wait(8):
        client.close()
        raise SystemExit(1)
    client.emit(Message("speak", {"utterance": sys.argv[2], "lang": sys.argv[1]},
                        {"source": "ovos-start-check"}))
    ended.wait(15)
    client.close()
except Exception:
    raise SystemExit(1)
OVOS_SOUND
}

check_setup() {
  printf '\n'; say health; check_services
  say resume
  printf '  sh "$HOME/.config/ovos-installer/check-setup.sh"\n'
  if [ "$ovos_experience" = hub ]; then say hub; say help; return 3; fi
  if ! ( : < /dev/tty ) 2>/dev/null; then say closed; return 3; fi
  while :; do
    terminal_choice checkMenu || { say incomplete; return 3; }
    case "$ovos_answer" in
      2) check_services; continue;;
      1) break;;
      *) say incomplete; return 3;;
    esac
  done
  while :; do
    say audioTest
    if ! sound_check; then say audioFailed; say help; break; fi
    terminal_choice audioQuestion || { say incomplete; return 3; }
    case "$ovos_answer" in
      1) say audioOk; break;;
      2) continue;;
      *) say incomplete; return 3;;
    esac
  done
  say voiceIntro
  if [ "$ovos_skills" = true ]; then say voicePhrase; else say customVoice; fi
  while :; do
    terminal_choice voiceQuestion || { say incomplete; return 3; }
    case "$ovos_answer" in
      1) say voiceOk; return 0;;
      2) say voiceIntro; [ "$ovos_skills" != true ] || say voicePhrase;;
      *) say incomplete; say help; return 3;;
    esac
  done
}
