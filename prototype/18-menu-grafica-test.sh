#!/usr/bin/env bash
# Aracno prototipo — T10: grafica del menù. Misura M1 da solo, poi ti fa guardare.
# Va lanciato SENZA sudo, dalla sessione grafica. Prima compila:
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno && \
#   PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig cargo build --release -p aracno-menu
# Screenshot di riferimento: docs/img/aracno-menu-t10.png
#
# Ipotesi e criteri (scritti prima del test):
#   M1 dal tasto (avvio del processo) alla finestra visibile < 200 ms in 5 aperture su 5
#      (misura del 2026-11-02 dopo la grafica: 152–166 ms)
#   G0 l'apertura animata gira ad almeno 45 fotogrammi al secondo (≥ 13 fotogrammi in 300 ms),
#      misurato dal menù stesso, in 5 aperture su 5
#   G1 la ragnatela c'è subito; i fili arrivano uno dopo l'altro scorrendo lungo il loro
#      filo, in modo fluido (~1/3 s)
#   G2 lo stato di ogni filo si legge come testo e simbolo; il filo attivo è l'unico colorato
#   G3 il filo selezionato ha un anello ben visibile che segue le frecce
#   G4 niente fa pensare a un ragno: solo fili e ragnatela leggera
#   Nessun "Broken pipe", CRITICAL o panic nel log.
# Correzione dopo il primo giro (2026-11-02): G1 FAIL, l'apertura era a scatti. Misurato:
# 9 fotogrammi in 266 ms (~30 al secondo). Cause: motore OpenGL lento su questa scheda,
# fondo semitrasparente, ragnatela ridisegnata a ogni fotogramma. Ora: motore cairo, fondo
# opaco, ragnatela ferma e solo i nodi animati. Aggiunto G0 (misura automatica).
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
M="$R/aracno/target/release/aracno-menu"
[[ -x $M ]] || { echo "Manca $M: compila prima (vedi l'intestazione)"; exit 1; }
LOG=$(mktemp); trap 'pkill -f "^$M" 2>/dev/null || true; rm -f "$LOG"' EXIT

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
chiedi() { local r; read -r -p "  ? $1 [s/n] " r </dev/tty; [[ $r == s* || $r == S* ]]; }
vivo() { pgrep -f "^$M" >/dev/null; }
pulito() { if grep -iE 'Broken pipe|CRITICAL|panic' "$LOG"; then fail "$1: errori nel log"; fi; }

"$M" --help >/dev/null 2>"$LOG" || { echo "  aracno-menu non parte:"; sed 's/^/    /' "$LOG"; exit 1; }

echo ">> M1: 5 aperture misurate (il menù si apre e si chiude da solo, non toccare niente)"
for i in 1 2 3 4 5; do
  : >"$LOG"; t=$(date +%s%3N)
  "$M" >>"$LOG" 2>&1 & pid=$!
  for _ in $(seq 30); do grep -q '@[0-9]' "$LOG" && break; sleep 0.1; done
  v=$(grep -o '@[0-9]*' "$LOG" | tail -1 | tr -d @)
  ms=$(( ${v:-0} - t ))
  [[ -n $v ]] && (( ms >= 0 && ms < 200 )) && ok "apertura $i: $ms ms" || fail "apertura $i: $ms ms"
  sleep 0.8
  f=$(sed -n 's/.*apertura animata in \([0-9]*\) fotogrammi.*/\1/p' "$LOG")
  [[ -n $f ]] && (( f >= 13 )) && ok "G0 apertura $i: $f fotogrammi in ~300 ms" || fail "G0 apertura $i: ${f:-?} fotogrammi"
  "$M" >>"$LOG" 2>&1; wait "$pid" || true
  pulito "apertura $i"
done

echo; echo ">> G1–G4: guarda l'apertura, prova le frecce, poi premi Esc e rispondi qui"
: >"$LOG"
"$M" >>"$LOG" 2>&1 & pid=$!
for _ in $(seq 1200); do vivo || break; sleep 0.1; done
wait "$pid" || true
pulito "G"
chiedi "G1: la ragnatela c'era subito e i fili sono arrivati uno dopo l'altro lungo il loro filo, in modo fluido?" && ok "G1" || fail "G1"
chiedi "G2: stato leggibile come testo e simbolo, e solo il filo attivo è colorato?" && ok "G2" || fail "G2"
chiedi "G3: il filo selezionato aveva un anello ben visibile che seguiva le frecce?" && ok "G3" || fail "G3"
chiedi "G4: niente faceva pensare a un ragno (solo fili e ragnatela)?" && ok "G4" || fail "G4"

echo
if (( fails == 0 )); then
  echo "ESITO T10: PASS (M1 < 200 ms, ragnatela, stati leggibili, selezione visibile)"
else
  echo "ESITO T10: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
