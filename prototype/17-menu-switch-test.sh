#!/usr/bin/env bash
# Aracno prototipo — T9: ragnatela, tastiera e switch dal menù. Test guidato: lo script
# apre il menù e ti dice cosa premere; poi controlla da solo il risultato.
# Va lanciato SENZA sudo, dalla sessione grafica. Prima compila:
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno && \
#   PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig cargo build --release -p aracno-menu
#
# Ipotesi e criteri (scritti prima del test):
#   R1 all'apertura i fili sono disposti intorno al centro "aracno", il filo attivo in alto
#      e già selezionato (focus visibile)
#   M3 solo tastiera: frecce fino ad arch, Invio → il menù si chiude da solo (uscita 0),
#      il log dice "switch arch ok", `aracno where` dice arch
#   M3b Tab invece delle frecce: Tab fino a debian, Invio → debian attivo
#   M2 col mouse: clic su arch → arch attivo, menù chiuso
#   R2 Invio sul filo già attivo: il menù si chiude senza switch (niente "switch" nel log)
# Correzione dopo il primo giro (2026-11-02): le frecce spostavano la selezione senza
# mostrarla (focus-visible spento), e in R2 Invio ha fatto passare a debian. Aggiunto:
#   R1b l'evidenziazione si sposta subito a ogni freccia; ogni prova stampa la traccia
#       di frecce, Tab e Invio dal log del menù
#   In nessun caso "Broken pipe", CRITICAL o panic nel log.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
M="$R/aracno/target/release/aracno-menu"
A=/usr/local/bin/aracno
[[ -x $M ]] || { echo "Manca $M: compila prima (vedi l'intestazione)"; exit 1; }
LOG=$(mktemp); trap 'pkill -f "^$M" 2>/dev/null || true; rm -f "$LOG"' EXIT

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
chiedi() { local r; read -r -p "  ? $1 [s/n] " r </dev/tty; [[ $r == s* || $r == S* ]]; }
vivo() { pgrep -f "^$M" >/dev/null; }

# prova ISTRUZIONE FILO_ATTESO: apre il menù, aspetta che si chiuda, controlla il risultato
prova() {
  local istr=$1 atteso=$2 rc=0 dove
  echo "  → $istr"
  : >"$LOG"
  "$M" >>"$LOG" 2>&1 & local pid=$!
  for _ in $(seq 1200); do vivo || break; sleep 0.1; done
  if vivo; then fail "il menù è ancora aperto dopo 2 minuti"; pkill -f "^$M"; return; fi
  wait "$pid" || rc=$?
  grep 'aracno-menu:' "$LOG" | grep -v visibile | sed 's/^aracno-menu: /    traccia: /'
  (( rc == 0 )) && ok "menù chiuso, uscita 0" || fail "uscita $rc"
  if grep -iE 'Broken pipe|CRITICAL|panic' "$LOG"; then fail "errori nel log"; fi
  dove=$("$A" where 2>&1 || true)
  [[ $dove == "$atteso" ]] && ok "filo attivo: $dove" || fail "filo attivo: $dove (atteso $atteso)"
}

"$M" --help >/dev/null 2>"$LOG" || { echo "  aracno-menu non parte:"; sed 's/^/    /' "$LOG"; exit 1; }
"$A" hop debian >/dev/null
"$A" web | sed 's/^/    /'

echo; echo ">> R1 + M3: solo tastiera, frecce"
prova "guarda la disposizione, poi con le FRECCE vai su arch e premi Invio" arch
grep -q 'switch arch ok' "$LOG" && ok "log: $(grep -o 'switch arch ok in [0-9]* ms' "$LOG")" || fail "nessuno switch nel log"
chiedi "I fili erano disposti intorno al centro \"aracno\", con debian in alto e già evidenziato?" \
  && ok "R1 disposizione e focus" || fail "R1 disposizione e focus"
chiedi "L'evidenziazione si spostava SUBITO a ogni freccia, senza premere Tab?" \
  && ok "R1b frecce visibili" || fail "R1b frecce visibili"

echo; echo ">> M3b: solo tastiera, Tab"
prova "con TAB vai su debian e premi Invio" debian

echo; echo ">> M2: mouse"
prova "CLICCA su arch" arch

echo; echo ">> R2: Invio sul filo già attivo"
prova "premi subito INVIO, senza toccare le frecce (è evidenziato arch, già attivo)" arch
grep -q 'switch' "$LOG" && fail "c'è stato uno switch inutile" || ok "nessuno switch"

echo; echo ">> Ripristino: debian attiva"
"$A" hop debian | sed 's/^/    /'

echo
if (( fails == 0 )); then
  echo "ESITO T9: PASS (ragnatela, frecce, Tab, Invio, clic, switch dal menù)"
else
  echo "ESITO T9: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
