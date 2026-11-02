#!/usr/bin/env bash
# Aracno prototipo — T1: prova del modello di permessi di aracnod (utente "aracno" + regola polkit).
# Installa l'utente di sistema e la regola, poi prova con busctl cosa può e non può fare "aracno".
# Lascia installati utente e regola (servono a T5). Per rimuoverli: lo stesso script con --rimuovi.
#
# Ipotesi e criteri (scritti prima del test):
#   P1  come aracno, ThawUnit e FreezeUnit su systemd-nspawn@arch.service funzionano senza password
#   P2  come aracno, RestartUnit e KillUnit sullo stesso filo vengono rifiutati (verbi non concessi)
#   P3  come aracno, StopUnit su una unit che non è un filo viene rifiutato e la unit resta attiva
#   P4  come aracno, StartUnit su un nome non valido (systemd-nspawn@Arch.service) viene rifiutato
#   P5  come nobody, FreezeUnit sul filo viene rifiutato (la regola non vale per altri utenti)
#   P0  (aggiunta dopo il primo giro) la policy D-Bus di systemd 255 vieta FreezeUnit/ThawUnit ai
#       non-root: aracno-systemd-freezer.conf li apre SOLO a aracno; decide comunque polkit
#   P6  come aracno, ListImages di machined restituisce debian e arch, e la proprietà FreezerState
#       e memory.current del filo si leggono senza privilegi
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
SYSUSERS=/etc/sysusers.d/aracno.conf
RULES=/etc/polkit-1/rules.d/50-aracno.rules
BUSPOL=/etc/dbus-1/system.d/aracno-systemd-freezer.conf
T=systemd-nspawn@arch.service
DUMMY=aracno-spike-dummy.service

case ${1:-} in
  ""|--rimuovi) ;;
  *) echo "Opzione sconosciuta: $*  (uso: $0 [--rimuovi])"; exit 2 ;;
esac
if [[ ${1:-} == --rimuovi ]]; then
  rm -f "$RULES" "$SYSUSERS" "$BUSPOL"
  busctl call --system org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig
  id aracno >/dev/null 2>&1 && userdel aracno
  echo "rimossi regola polkit, policy D-Bus, sysusers e utente aracno"; exit 0
fi

echo ">> Installazione"
install -D -m 644 "$R/aracno/data/sysusers/aracno.conf" "$SYSUSERS"
systemd-sysusers "$SYSUSERS"
install -D -m 644 "$R/aracno/data/polkit/50-aracno.rules" "$RULES"
# systemd 255 non permette FreezeUnit/ThawUnit ai non-root sul bus: si apre solo a aracno
install -D -m 644 "$R/aracno/data/dbus/aracno-systemd-freezer.conf" "$BUSPOL"
busctl call --system org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig
id aracno
sleep 2   # polkitd rilegge rules.d da solo (inotify)

as()   { local u=$1; shift; runuser -u "$u" -- "$@"; }
sd()   { as "$1" busctl call --system org.freedesktop.systemd1 /org/freedesktop/systemd1 \
           org.freedesktop.systemd1.Manager "${@:2}"; }
fstate() { systemctl show -P FreezerState "$T"; }
fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
deny() {  # deny DESCRIZIONE UTENTE ARGOMENTI... — deve fallire per PERMESSI, non per altri motivi
  local d=$1 out; shift
  if out=$(sd "$@" 2>&1); then
    fail "$d: PERMESSO (doveva essere rifiutato)"
  elif grep -qiE 'access denied|not authorized|authentication|permission' <<<"$out"; then
    ok "$d rifiutato ($out)"
  else
    fail "$d: errore non di permessi, il rifiuto non è dimostrato ($out)"
  fi
}

echo; echo ">> Preparazione: debian attiva, arch congelata"
for n in debian arch; do systemctl is-active -q "systemd-nspawn@$n.service" || "$O" start "$n"; done
"$O" switch debian >/dev/null
systemd-run --unit="$DUMMY" --quiet sleep 600
echo "  arch: $(fstate)"

echo; echo ">> P1: thaw e freeze come aracno"
allow() {  # allow DESCRIZIONE STATO_ATTESO ARGOMENTI... — deve riuscire e portare arch allo stato atteso
  local d=$1 atteso=$2 out; shift 2
  if out=$(sd aracno "$@" 2>&1) && [[ $(fstate) == "$atteso" ]]; then ok "$d (arch: $(fstate))"
  else fail "$d (arch: $(fstate)) — ${out:-nessun output}"; fi
}
allow ThawUnit   running ThawUnit s "$T"
allow FreezeUnit frozen  FreezeUnit s "$T"

echo; echo ">> P2: verbi non concessi sul filo"
"$O" thaw arch
deny "RestartUnit arch" aracno RestartUnit ss "$T" replace
deny "KillUnit arch"    aracno KillUnit ssi "$T" all 18
systemctl is-active -q "$T" && ok "arch ancora attiva" || fail "arch non è più attiva"

echo; echo ">> P3: unit che non è un filo"
deny "StopUnit $DUMMY" aracno StopUnit ss "$DUMMY" replace
systemctl is-active -q "$DUMMY" && ok "$DUMMY ancora attiva" || fail "$DUMMY è stata fermata"

echo; echo ">> P4: nome non valido"
deny "StartUnit systemd-nspawn@Arch.service" aracno StartUnit ss systemd-nspawn@Arch.service replace

echo; echo ">> P5: un altro utente (nobody)"
deny "FreezeUnit arch come nobody" nobody FreezeUnit s "$T"
[[ $(fstate) == running ]] && ok "arch non congelata da nobody" || fail "arch: $(fstate)"

echo; echo ">> P6: letture senza privilegi come aracno"
imgs=$(as aracno busctl call --system org.freedesktop.machine1 /org/freedesktop/machine1 \
         org.freedesktop.machine1.Manager ListImages 2>&1 || true)
for n in debian arch; do
  grep -q "\"$n\"" <<<"$imgs" && ok "ListImages contiene $n" || fail "ListImages senza $n: $imgs"
done
fz=$(as aracno busctl get-property --system org.freedesktop.systemd1 \
       /org/freedesktop/systemd1/unit/systemd_2dnspawn_40arch_2eservice \
       org.freedesktop.systemd1.Unit FreezerState 2>&1 || true)
[[ $fz == *running* || $fz == *frozen* ]] && ok "FreezerState leggibile ($fz)" || fail "FreezerState: $fz"
mem=$(as aracno cat /sys/fs/cgroup/machine.slice/systemd-nspawn@arch.service/memory.current 2>&1 || true)
[[ $mem =~ ^[0-9]+$ ]] && ok "memory.current leggibile ($mem)" || fail "memory.current: $mem"

echo; echo ">> Pulizia"
systemctl stop "$DUMMY" 2>/dev/null || true
"$O" switch debian >/dev/null
"$O" list | sed 's/^/  /'

echo
if (( fails == 0 )); then
  echo "ESITO T1: PASS (aracno può solo start/stop/freeze/thaw sui fili; letture ok)"
  echo "Utente e regola restano installati per T5. Rimozione: stesso script con --rimuovi"
else
  echo "ESITO T1: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
