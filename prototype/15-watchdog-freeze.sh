#!/usr/bin/env bash
# Aracno prototipo — un filo congelato per più di 3 minuti deve sopravvivere allo scongelamento.
# Bug trovato il 2026-11-02: arch congelata è stata uccisa dal watchdog di systemd-nspawn@.service
# (WatchdogSec=3min, "Failed with result 'watchdog'", SIGABRT allo scongelamento).
#
# Ipotesi: il watchdog scatta perché systemd-nspawn, congelato col filo, non può farsi sentire.
# Correzione: drop-in aracno/data/systemd/systemd-nspawn@.service.d/aracno-watchdog.conf (WatchdogSec=0).
#
# Criteri (scritti prima del test):
#   W1 dopo il drop-in e il riavvio di arch: WatchdogUSec di systemd-nspawn@arch = 0
#   W2 arch congelata per ATTESA secondi (default 240, oltre i 3 minuti), poi scongelata:
#      stesso MainPID, NRestarts invariato, ActiveState active, Result success,
#      systemd dentro arch risponde (running o degraded)
#   W3 lo stesso per debian, se si lancia con FILI="arch debian"
# Durata: circa 4 minuti e mezzo. Si lancia con sudo.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$R/aracno/data/systemd/systemd-nspawn@.service.d/aracno-watchdog.conf"
DST="/etc/systemd/system/systemd-nspawn@.service.d/aracno-watchdog.conf"
ATTESA=${ATTESA:-240}
FILI=${FILI:-arch}

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
u()    { echo "systemd-nspawn@$1.service"; }
p()    { systemctl show -P "$2" "$(u "$1")"; }
pronto() {
  for _ in $(seq 60); do
    s=$(systemctl -M "$1" is-system-running 2>/dev/null || true)
    [[ $s == running || $s == degraded ]] && { echo "$s"; return 0; }
    sleep 0.5
  done
  echo "${s:-nessuna risposta}"; return 1
}

echo ">> Installazione del drop-in"
install -D -m 644 "$SRC" "$DST"
systemctl daemon-reload
echo "  $DST"

echo; echo ">> W1: watchdog spento (i fili si riavviano per prendere la nuova impostazione)"
for n in $FILI; do
  # un filo congelato va scongelato prima di fermarlo (come fa plan_stop in aracnod)
  systemctl thaw "$(u "$n")" 2>/dev/null || true
  systemctl restart "$(u "$n")"
  pronto "$n" >/dev/null || true
  w=$(p "$n" WatchdogUSec)
  [[ $w == 0 ]] && ok "$n: WatchdogUSec=$w" || fail "$n: WatchdogUSec=$w (atteso 0)"
done

echo; echo ">> W2: congelamento lungo ($ATTESA s)"
declare -A pid0 nr0
for n in $FILI; do
  pid0[$n]=$(p "$n" MainPID); nr0[$n]=$(p "$n" NRestarts)
  systemctl freeze "$(u "$n")"
  echo "  $n congelato (pid ${pid0[$n]}, NRestarts ${nr0[$n]}, freezer $(p "$n" FreezerState))"
done
for ((t = ATTESA; t > 0; t -= 30)); do echo "  … mancano $t s"; sleep $(( t < 30 ? t : 30 )); done
for n in $FILI; do
  systemctl thaw "$(u "$n")"
  sleep 2
  s=$(pronto "$n" || true)
  a=$(p "$n" ActiveState); r=$(p "$n" Result); pid=$(p "$n" MainPID); nr=$(p "$n" NRestarts)
  echo "  $n: $a, result $r, pid $pid, NRestarts $nr, systemd interno: $s"
  [[ $a == active && $r == success ]] && ok "$n vivo" || fail "$n: $a / $r"
  [[ $pid == "${pid0[$n]}" && $nr == "${nr0[$n]}" ]] && ok "$n non riavviato" || fail "$n riavviato (pid ${pid0[$n]}→$pid)"
  [[ $s == running || $s == degraded ]] && ok "$n risponde" || fail "$n non risponde ($s)"
done
journalctl -u "$(u arch)" --since "-$((ATTESA + 60))s" --no-pager -o cat | grep -i watchdog \
  && fail "il journal parla ancora di watchdog" || ok "nessun watchdog nel journal"

echo; echo ">> Ripristino: debian attiva, arch congelata"
/usr/local/bin/aracno hop debian 2>/dev/null || "$R/prototype/aracno" switch debian

echo
if (( fails == 0 )); then
  echo "ESITO: PASS (un filo congelato oltre i 3 minuti sopravvive allo scongelamento)"
else
  echo "ESITO: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
