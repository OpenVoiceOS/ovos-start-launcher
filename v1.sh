#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# OVOS Start code protocol v1. Keep this decoder compatible with issued codes.
set -eu
set +x

fail() { printf '%s\n' "$*" >&2; exit 1; }

# Also protects 40-bit arithmetic on shells with a 32-bit userland.
[ "$(getconf LONG_BIT 2>/dev/null || true)" = 64 ] || fail 'OVOS needs a 64-bit operating system. No changes were made.'
ovos_mode=install
case "${1:-}" in
  --decode|--scenario) ovos_mode=${1#--}; shift;;
esac
[ "$#" = 1 ] || fail 'Paste the complete command from OVOS Start, including your setup code.'
case "$1" in ????????|????-????) :;; *) fail 'That setup code is not complete. Copy it again from OVOS Start.';; esac
ovos_code=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d '-')
[ "${#ovos_code}" = 8 ] || fail 'Invalid setup code.'
ovos_alphabet=0123456789ABCDEFGHJKMNPQRSTVWXYZ
ovos_word=0
ovos_rest=$ovos_code
while [ -n "$ovos_rest" ]; do
  ovos_char=${ovos_rest%"${ovos_rest#?}"}
  ovos_rest=${ovos_rest#?}
  case "$ovos_alphabet" in
    *"$ovos_char"*) ovos_prefix=${ovos_alphabet%%"$ovos_char"*}; ovos_digit=${#ovos_prefix};;
    *) fail 'That setup code contains an unexpected character. Copy it again.';;
  esac
  ovos_word=$((ovos_word * 32 + ovos_digit))
done
ovos_body=$((ovos_word / 256))
ovos_crc=0
ovos_shift=24
while [ "$ovos_shift" -ge 0 ]; do
  ovos_byte=$(((ovos_body >> ovos_shift) & 255))
  ovos_crc=$((ovos_crc ^ ovos_byte))
  ovos_bit=0
  while [ "$ovos_bit" -lt 8 ]; do
    if [ "$ovos_crc" -ge 128 ]; then ovos_crc=$((((ovos_crc * 2) ^ 7) & 255)); else ovos_crc=$((ovos_crc * 2)); fi
    ovos_bit=$((ovos_bit + 1))
  done
  ovos_shift=$((ovos_shift - 8))
done
[ "$ovos_crc" = "$((ovos_word & 255))" ] || fail 'That setup code looks mistyped. Copy it again from OVOS Start.'
[ "$((ovos_body >> 28))" = 1 ] || fail 'This setup code needs a different launcher version. Copy the complete command again.'
ovos_payload=$((ovos_body & 268435455))
ovos_remaining=28

# Read a fixed-width enum. Values come only from this trusted script, never eval.
take() {
  ovos_remaining=$((ovos_remaining - $1))
  ovos_index=$(((ovos_payload >> ovos_remaining) & ((1 << $1) - 1)))
  shift
  [ "$ovos_index" -lt "$#" ] || fail 'This setup code contains an unsupported choice.'
  while [ "$ovos_index" -gt 0 ]; do shift; ovos_index=$((ovos_index - 1)); done
  ovos_value=$1
}
take 4 pi computer mark1 mark2 devkit jetson server mac windows other; ovos_device=$ovos_value
take 2 ready tinker hub; ovos_experience=$ovos_value
take 4 en-us fr-fr de-de es-es it-it nl-nl pt-pt ca-es eu-es gl-es hi-in kab-dz; ovos_locale=$ovos_value
take 1 virtualenv containers; ovos_method=$ovos_value
take 1 testing alpha; ovos_channel=$ovos_value
take 2 guided tinker expert; ovos_expertise=$ovos_value
take 2 auto public local; ovos_speech=$ovos_value
take 2 unknown under8 8plus; ovos_memory=$ovos_value
take 2 unknown arm64 avx2 intel-mac; ovos_cpu=$ovos_value
take 2 unknown older pi5; ovos_pi=$ovos_value
take 2 off local online; ovos_llm=$ovos_value
take 1 false true; ovos_extra=$ovos_value
take 1 false true; ovos_telemetry=$ovos_value
take 1 false true; ovos_skills=$ovos_value
take 1 false true; ovos_ha=$ovos_value

invalid() { fail 'These setup choices do not fit together. Open OVOS Start and make a new setup.'; }
case "$ovos_device:$ovos_experience" in server:ready|server:tinker|mark1:hub|mark2:hub|devkit:hub) invalid;; esac
case "$ovos_device" in
  mark2|devkit|mac) [ "$ovos_method:$ovos_channel" = virtualenv:alpha ] || invalid;;
  mark1|windows) [ "$ovos_method" = virtualenv ] || invalid;;
esac
[ "$ovos_extra:$ovos_skills" != true:false ] || invalid
if [ "$ovos_experience" = hub ]; then
  [ "$ovos_speech:$ovos_ha:$ovos_llm" = auto:false:off ] || invalid
  [ "$ovos_method:$ovos_extra" != containers:true ] || invalid
fi
if [ "$ovos_speech" = local ]; then
  [ "$ovos_method:$ovos_channel:$ovos_memory" = virtualenv:alpha:8plus ] || invalid
  case "$ovos_locale" in hi-in|kab-dz) invalid;; esac
  case "$ovos_device" in
    mark1|mark2|devkit) invalid;;
    pi) [ "$ovos_pi:$ovos_cpu" = pi5:arm64 ] || invalid;;
    jetson|mac) [ "$ovos_cpu" = arm64 ] || invalid;;
  esac
  case "$ovos_cpu" in arm64|avx2) :;; *) invalid;; esac
fi

scenario() {
  printf '%s\n' '# Created with OVOS Start · contract checked 2026-10-06' 'uninstall: false' "method: $ovos_method" "channel: $ovos_channel"
  if [ "$ovos_experience" = hub ]; then printf '%s\n' 'profile: server'; else printf '%s\n' 'profile: ovos'; fi
  [ "$ovos_speech" = auto ] || printf '%s\n' "speech_engine: $ovos_speech"
  ovos_gui=false
  case "$ovos_device" in mark2|devkit) ovos_gui=true; printf '%s\n' "hardware: $ovos_device";; esac
  ovos_has_llm=false; [ "$ovos_llm" = off ] || ovos_has_llm=true
  printf '%s\n' 'features:' "  skills: $ovos_skills" "  extra_skills: $ovos_extra" "  gui: $ovos_gui" "  homeassistant: $ovos_ha" "  llm: $ovos_has_llm" 'raspberry_pi_tuning: false' "share_telemetry: $ovos_telemetry" 'share_usage_telemetry: false'
}
if [ "$ovos_mode" = decode ]; then
  printf '{"device":"%s","experience":"%s","locale":"%s","method":"%s","channel":"%s","expertise":"%s","speech":"%s","memory":"%s","cpu":"%s","piModel":"%s","llmMode":"%s","extraSkills":%s,"telemetry":%s,"skills":%s,"homeassistant":%s}\n' "$ovos_device" "$ovos_experience" "$ovos_locale" "$ovos_method" "$ovos_channel" "$ovos_expertise" "$ovos_speech" "$ovos_memory" "$ovos_cpu" "$ovos_pi" "$ovos_llm" "$ovos_extra" "$ovos_telemetry" "$ovos_skills" "$ovos_ha"
  exit 0
fi
if [ "$ovos_mode" = scenario ]; then scenario; exit 0; fi

[ "$(id -u)" -ne 0 ] || fail 'Run this command from your regular user account, without sudo.'
if [ "$ovos_device" = mac ]; then
  [ "$(uname -s)" = Darwin ] || fail 'This setup is for a Mac. Run it in Terminal on that Mac.'
else
  [ "$(uname -s)" = Linux ] || fail 'Run this on your Linux device. On Windows, open Ubuntu in WSL2.'
fi
for ovos_program in curl git sudo; do command -v "$ovos_program" >/dev/null 2>&1 || fail "Install $ovos_program first, then paste this command again."; done
[ ! -e "$HOME/ovos-installer" ] && [ ! -L "$HOME/ovos-installer" ] || fail 'Move ~/ovos-installer aside first. Your existing checkout has not been changed.'
printf '\n%s\n' 'Your OVOS setup is here. Let’s get it installed.'
printf 'Language: %s · Device: %s\n' "$ovos_locale" "$ovos_device"
if [ "$ovos_speech" != auto ]; then printf '%s\n' 'Uses the reviewed experimental speech installer (PR #648).'; fi
umask 077
ovos_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ovos-start.XXXXXX")
trap 'rm -rf "$ovos_tmp"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
ovos_source="$ovos_tmp/installer.sh"
if [ "$ovos_speech" != auto ]; then
  ovos_source="$ovos_tmp/source"
  mkdir "$ovos_source"
  git -C "$ovos_source" init --quiet
  git -C "$ovos_source" fetch --quiet --depth=1 https://github.com/OpenVoiceOS/ovos-installer.git 6ffd465028bac299e5235d619819bfdc734af073
  git -C "$ovos_source" checkout --quiet --detach FETCH_HEAD
  [ "$(git -C "$ovos_source" rev-parse HEAD)" = 6ffd465028bac299e5235d619819bfdc734af073 ] || fail 'The installer revision could not be verified.'
else
  curl -fsSL https://raw.githubusercontent.com/OpenVoiceOS/ovos-installer/main/installer.sh -o "$ovos_source"
fi
ovos_cfg="$HOME/.config/ovos-installer"
mkdir -p "$ovos_cfg"
if [ -e "$ovos_cfg/scenario.yaml" ] || [ -L "$ovos_cfg/scenario.yaml" ]; then
  ovos_backup=$(mktemp "$ovos_cfg/scenario.yaml.backup.XXXXXX")
  cp -p "$ovos_cfg/scenario.yaml" "$ovos_backup"
  printf 'Previous settings saved to %s\n' "$ovos_backup"
fi
scenario > "$ovos_tmp/scenario.yaml"
cat > "$ovos_tmp/launch.sh" <<'OVOS_LAUNCH'
#!/bin/sh
set -eu
set +x
umask 077
ovos_source=$1
ovos_home=$2
ovos_scenario=$3
export LOCALE="$4"
ovos_speech=$5
ovos_ha=$6
ovos_llm=$7
ovos_tty=''
restore_tty() { [ -z "$ovos_tty" ] || stty "$ovos_tty" < /dev/tty; }
cleanup_launcher() {
  restore_tty
  if [ "$ovos_speech" != auto ]; then
    case "$ovos_source" in */ovos-start.??????/source) cd /; rm -rf "$ovos_source";; esac
  fi
}
trap cleanup_launcher 0
trap 'exit 130' INT
trap 'exit 143' TERM
if [ "$ovos_speech" != auto ]; then
  cd "$ovos_source"
  . ./utils/bash_runtime.sh
  ovos_bash=$(resolve_bash_runtime 4 || true)
  [ -n "$ovos_bash" ] || { printf '%s\n' 'Install Bash 4+ first.' >&2; exit 1; }
fi
valid_url() { case "$1" in http://?*|https://?*) return 0;; *) printf '%s\n' 'Use an absolute http:// or https:// service URL.' > /dev/tty; return 1;; esac; }
read_value() { printf '%s' "$2" > /dev/tty; IFS= read -r "$1" < /dev/tty; }
read_secret() {
  ovos_tty=$(stty -g < /dev/tty)
  stty -echo < /dev/tty
  printf '%s' "$2" > /dev/tty
  IFS= read -r "$1" < /dev/tty
  restore_tty; ovos_tty=''
  printf '\n' > /dev/tty
}
if [ "$ovos_ha" = true ]; then
  read_value HOMEASSISTANT_URL 'Home Assistant URL: '
  read_secret HOMEASSISTANT_API_KEY 'Home Assistant long-lived token: '
  [ -n "$HOMEASSISTANT_URL" ] && [ -n "$HOMEASSISTANT_API_KEY" ] || exit 1
  valid_url "$HOMEASSISTANT_URL" || exit 1
  export HOMEASSISTANT_URL HOMEASSISTANT_API_KEY
fi
if [ "$ovos_llm" != off ]; then
  if [ "$ovos_llm" = local ]; then
    printf '%s\n' 'Connect your existing local OpenAI-compatible model server.' > /dev/tty
  else
    printf '%s\n' 'Connect your chosen online OpenAI-compatible provider. Its usage charges may apply.' > /dev/tty
  fi
  read_value LLM_API_URL 'OpenAI-compatible API URL: '
  read_value LLM_MODEL 'Model name: '
  read_secret LLM_API_KEY 'API key (or provider-required placeholder for a keyless local endpoint): '
  [ -n "$LLM_API_URL" ] && [ -n "$LLM_MODEL" ] && [ -n "$LLM_API_KEY" ] || exit 1
  valid_url "$LLM_API_URL" || exit 1
  case "$LOCALE" in
    en-us) ovos_language='English (US)';; fr-fr) ovos_language='Français';; de-de) ovos_language='Deutsch';;
    es-es) ovos_language='Español';; it-it) ovos_language='Italiano';; nl-nl) ovos_language='Nederlands';;
    pt-pt) ovos_language='Português';; ca-es) ovos_language='Català';; eu-es) ovos_language='Euskara';;
    gl-es) ovos_language='Galego';; hi-in) ovos_language='हिन्दी';; kab-dz) ovos_language='Taqbaylit';;
  esac
  LLM_PERSONA="Respond concisely in $ovos_language for a voice assistant. Use plain spoken language without Markdown or emojis."
  LLM_MAX_TOKENS=300; LLM_TEMPERATURE=0.2; LLM_TOP_P=0.1
  export LLM_API_URL LLM_API_KEY LLM_MODEL LLM_PERSONA LLM_MAX_TOKENS LLM_TEMPERATURE LLM_TOP_P
fi
mv "$ovos_scenario" "$ovos_home/.config/ovos-installer/scenario.yaml"
if [ "$ovos_speech" != auto ]; then
  export RUN_AS="$SUDO_USER"
  export RUN_AS_HOME="$ovos_home"
  "$ovos_bash" setup.sh
else
  sh "$ovos_source"
fi
OVOS_LAUNCH
sudo sh "$ovos_tmp/launch.sh" "$ovos_source" "$HOME" "$ovos_tmp/scenario.yaml" "$ovos_locale" "$ovos_speech" "$ovos_ha" "$ovos_llm"
