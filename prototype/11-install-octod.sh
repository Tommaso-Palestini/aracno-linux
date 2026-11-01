#!/usr/bin/env bash
# Octopus prototipo — T5: installa octod (installazione di sviluppo) e verifica ListTentacles.
# Prima compila come utente:  cd octopus && cargo build --release -p octod
# Percorsi di sviluppo (i pacchetti useranno /usr/share e /usr/lib):
#   /usr/local/libexec/octod                                        binario
#   /etc/dbus-1/system.d/io.github.tommaso_palestini.Octopus1.conf  policy del nome
#   /usr/local/share/dbus-1/system-services/…Octopus1.service       attivazione via D-Bus
#   /etc/systemd/system/octod.service                               unit con restrizioni
#   /usr/share/polkit-1/actions/…Octopus1.policy                    azioni switch e manage
# Reinstalla anche i file di T1 (utente octopus, regola polkit, policy freeze/thaw).
#
# Ipotesi e criteri (scritti prima del test):
#   O1a ListTentacles, chiamato da un utente normale, restituisce debian e arch con lo stesso
#       stato di `octo list` (attiva→active, congelata→frozen, spenta→off)
#   O1b RAM > 0 per i tentacoli accesi, 0 per quelli spenti
#   O1c con arch spenta, arch risulta "off" (caso della unit non caricata o inattiva)
#   O1d octod gira come utente octopus, attivato dal bus, senza errori nel journal
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
D="$R/octopus/data"
O="$R/prototype/octo"
BIN_SRC="$R/octopus/target/release/octod"
NAME=io.github.tommaso_palestini.Octopus1
BIN=/usr/local/libexec/octod
BUSCONF=/etc/dbus-1/system.d/$NAME.conf
ACTIV=/usr/local/share/dbus-1/system-services/$NAME.service
UNIT=/etc/systemd/system/octod.service
# polkit legge le azioni solo da /usr/share/polkit-1/actions (non da /usr/local)
ACTIONS=/usr/share/polkit-1/actions/$NAME.policy
UTENTE=${SUDO_USER:-xenon}

reload_bus() { busctl call --system org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig; }

case ${1:-} in
  "") ;;
  --rimuovi)
    systemctl stop octod.service 2>/dev/null || true
    rm -f "$BIN" "$BUSCONF" "$ACTIV" "$UNIT" "$ACTIONS"
    systemctl daemon-reload; reload_bus
    echo "octod rimosso (i file di T1 restano: prototype/10-polkit-spike.sh --rimuovi)"; exit 0 ;;
  *) echo "Opzione sconosciuta: $*  (uso: $0 [--rimuovi])"; exit 2 ;;
esac

[[ -x $BIN_SRC ]] || { echo "Manca $BIN_SRC. Compila prima: cd $R/octopus && cargo build --release -p octod"; exit 1; }

echo ">> Installazione"
install -D -m 644 "$D/sysusers/octopus.conf" /etc/sysusers.d/octopus.conf
systemd-sysusers /etc/sysusers.d/octopus.conf
install -D -m 644 "$D/polkit/50-octopus.rules" /etc/polkit-1/rules.d/50-octopus.rules
install -D -m 644 "$D/dbus/octopus-systemd-freezer.conf" /etc/dbus-1/system.d/octopus-systemd-freezer.conf
install -D -m 755 -o root -g root "$BIN_SRC" "$BIN"
install -D -m 644 "$D/dbus/$NAME.conf" "$BUSCONF"
install -D -m 644 "$D/dbus/$NAME.service" "$ACTIV"
install -D -m 644 "$D/systemd/octod.service" "$UNIT"
install -D -m 644 "$D/polkit/$NAME.policy" "$ACTIONS"
systemctl daemon-reload
reload_bus
systemctl stop octod.service 2>/dev/null || true   # la prossima chiamata attiva il binario nuovo
echo "  installato: $BIN ($(sha256sum "$BIN" | cut -c1-16)…)"
T0=$(date '+%Y-%m-%d %H:%M:%S')

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }

# ListTentacles chiamato dall'utente normale; stampa "nome stato ram limite" per riga
lista() {
  runuser -u "$UTENTE" -- busctl call --system --json=short "$NAME" /io/github/tommaso_palestini/Octopus1 \
    "$NAME.Manager" ListTentacles \
  | python3 -c 'import sys,json; [print(*r) for r in json.load(sys.stdin)["data"][0]]'
}
atteso() { case $1 in attiva) echo active ;; congelata) echo frozen ;; spenta) echo off ;; *) echo "?" ;; esac; }
octo_stato() { "$O" list | awk -v n="$1" '$1 == n {print $2}'; }

confronta() {  # confronta lo stato di octod con quello di octo list per debian e arch
  local out; out=$(lista) || { fail "ListTentacles fallita"; return; }
  echo "$out" | sed 's/^/    octod: /'
  for n in debian arch; do
    local riga st ram exp
    riga=$(awk -v n="$n" '$1 == n' <<<"$out")
    [[ -n $riga ]] || { fail "$n assente da ListTentacles"; continue; }
    read -r _ st ram _ <<<"$riga"
    exp=$(atteso "$(octo_stato "$n")")
    [[ $st == "$exp" ]] && ok "$n: $st (octo list: $(octo_stato "$n"))" || fail "$n: octod dice $st, octo list $exp"
    if [[ $st == off ]]; then (( ram == 0 )) || fail "$n spenta ma RAM $ram"
    else (( ram > 0 )) || fail "$n accesa ma RAM 0"; fi
  done
}

echo; echo ">> O1a/O1b: debian attiva, arch congelata"
for n in debian arch; do [[ $(octo_stato "$n") != spenta ]] || "$O" start "$n" >/dev/null; done
"$O" switch debian >/dev/null
confronta

echo; echo ">> O1c: arch spenta"
"$O" stop arch >/dev/null
for _ in $(seq 20); do [[ $(octo_stato arch) == spenta ]] && break; sleep 0.5; done
confronta

echo; echo ">> O1d: utente del processo e journal"
pid=$(systemctl show -P MainPID octod.service)
u=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
[[ $u == octopus ]] && ok "octod (pid $pid) gira come $u" || fail "octod gira come '${u:-?}' (pid $pid)"
errori=$(journalctl -u octod.service --since "$T0" --no-pager -o cat | grep -i "errore\|error" || true)
[[ -z $errori ]] && ok "nessun errore nel journal" || { fail "errori nel journal:"; echo "$errori" | sed 's/^/    /'; }

echo; echo ">> Ripristino: arch riaccesa e congelata"
"$O" start arch >/dev/null; "$O" switch debian >/dev/null

echo
if (( fails == 0 )); then
  echo "ESITO T5: PASS (octod installato, ListTentacles coerente con octo list)"
else
  echo "ESITO T5: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
