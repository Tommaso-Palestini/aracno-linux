#!/usr/bin/env bash
# Aracno prototipo — T8: menù base (aracno-menu). Test guidato: lo script apre il menù,
# tu guardi lo schermo e rispondi s/n. Va lanciato SENZA sudo, dalla sessione grafica.
# Prima compila:
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno && \
#   PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig cargo build --release -p aracno-menu
#
# Ipotesi e criteri (scritti prima del test):
#   B1 il menù copre tutto lo schermo (pannelli compresi), modo layer-shell, mostra debian
#      e arch con simbolo, stato in testo e RAM, il filo attivo per primo
#   B2 dal "tasto" (avvio del processo) alla finestra visibile: < 200 ms (M1), misurato 3 volte
#   B3 un secondo avvio con il menù aperto lo chiude: il processo del menù esce con codice 0
#   B5 Esc chiude il menù: il processo esce con codice 0
#   M4 bus di sistema irraggiungibile: messaggio d'errore chiaro con ⚠, nessun crash, Esc chiude
#   In nessun caso il log contiene "Broken pipe", CRITICAL o panic.
# Correzione dopo il primo giro (2026-11-02): nascondere o chiudere la finestra layer-shell
# fa cadere la connessione con COSMIC ("Error reading events from display: Broken pipe"),
# quindi il menù non resta in memoria: chiudere = uscire dal processo. B3 e B5 cambiano di
# conseguenza (prima: "il processo resta"), B4 (riapertura da processo caldo) non esiste più.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
M="$R/aracno/target/release/aracno-menu"
[[ -x $M ]] || { echo "Manca $M: compila prima (vedi l'intestazione)"; exit 1; }
LOG=$(mktemp); trap 'pkill -f "^$M" 2>/dev/null || true; rm -f "$LOG"' EXIT

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
chiedi() {  # chiedi DOMANDA → vero se la risposta è s
  local r; read -r -p "  ? $1 [s/n] " r </dev/tty; [[ $r == s* || $r == S* ]]
}
vivo() { pgrep -f "^$M" >/dev/null; }
# apri: lancia il menù in background (PID), aspetta la finestra; MS = ms dal tasto alla finestra
apri() {
  local t v
  : >"$LOG"; t=$(date +%s%3N)
  "$M" >>"$LOG" 2>&1 & PID=$!
  for _ in $(seq 30); do grep -q '@[0-9]' "$LOG" && break; sleep 0.1; done
  vivo || { echo "  aracno-menu è uscito subito:"; sed 's/^/    /' "$LOG"; exit 1; }
  v=$(grep -o '@[0-9]*' "$LOG" | tail -1 | tr -d @)
  if [[ -n $v ]]; then MS=$(( v - t )); else MS="?"; fi
}
uscito_bene() {  # uscito_bene DESCRIZIONE [SECONDI]: il processo PID finisce con codice 0
  local rc=0 attesa=${2:-2}
  for _ in $(seq $(( attesa * 10 ))); do vivo || break; sleep 0.1; done
  if vivo; then fail "$1: il processo è ancora vivo"; return; fi
  wait "$PID" || rc=$?
  (( rc == 0 )) && ok "$1: processo uscito con codice 0" || fail "$1: codice di uscita $rc"
}
log_pulito() {
  if grep -iE 'Broken pipe|CRITICAL|panic' "$LOG"; then fail "$1: errori nel log"; else ok "$1: log pulito"; fi
}

pkill -f "^$M" 2>/dev/null || true; sleep 0.3
/usr/local/bin/aracno web 2>/dev/null | sed 's/^/    /' || true
"$M" --help >/dev/null 2>"$LOG" || { echo "  aracno-menu non parte:"; sed 's/^/    /' "$LOG"; exit 1; }

echo; echo ">> B1/B5: guarda il menù, premi Esc per chiuderlo, poi rispondi qui"
apri
grep -q 'layer-shell' "$LOG" && ok "modo layer-shell" || fail "modo: $(cat "$LOG")"
echo "    dal tasto alla finestra: $MS ms (aspetto che premi Esc…)"
uscito_bene "B5 Esc" 120
log_pulito "B5"
chiedi "Hai visto il menù a tutto schermo con debian (attivo, per primo) e arch, con simbolo, stato e RAM?" \
  && ok "B1 contenuto" || fail "B1 contenuto"

echo; echo ">> B2/B3: tasto rapido simulato 3 volte (apre, poi un secondo avvio chiude). Non toccare niente."
for i in 1 2 3; do
  apri
  [[ $MS =~ ^[0-9]+$ ]] && (( MS < 200 )) && ok "B2 giro $i: $MS ms (< 200)" || fail "B2 giro $i: $MS ms"
  sleep 0.5; "$M" >>"$LOG" 2>&1
  uscito_bene "B3 giro $i"
  log_pulito "B3 giro $i"
done

echo; echo ">> M4: bus di sistema irraggiungibile: leggi il messaggio, premi Esc, poi rispondi qui"
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent
apri
unset DBUS_SYSTEM_BUS_ADDRESS
echo "    (aspetto che premi Esc…)"
uscito_bene "M4 Esc" 120
log_pulito "M4"
chiedi "Il menù mostrava un messaggio d'errore chiaro con ⚠ invece dei fili?" && ok "M4 messaggio" || fail "M4 messaggio"

echo
if (( fails == 0 )); then
  echo "ESITO T8: PASS (menù base: layer-shell, elenco, apri/chiudi < 200 ms, Esc, errore chiaro)"
else
  echo "ESITO T8: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
