#!/usr/bin/env bash
# Aracno prototipo — T11: aggiornamenti in diretta, traduzioni, voce nelle applicazioni,
# tasto rapido Super+Shift+A. Test guidato, SENZA sudo, dalla sessione grafica.
# Prima: sudo prototype/11-install-aracnod.sh (installa menù, .desktop, traduzione) e
#        prototype/20-tasto-rapido.sh (scorciatoia).
#
# Ipotesi e criteri (scritti prima del test):
#   I1 installati: /usr/local/bin/aracno-menu, la voce .desktop, la traduzione inglese
#   I2 la scorciatoia Super+Shift+A → aracno-menu è nella configurazione di COSMIC
#   L1 con il menù aperto, uno switch fatto da un altro programma (`aracno hop`) aggiorna
#      il menù da solo: il filo colorato e "sei su …" cambiano senza riaprirlo
#   L2 con il sistema in inglese (LANG=en_US) i testi del menù sono in inglese
#   S1 Super+Shift+A apre il menù; premuto di nuovo lo chiude (rilevato dallo script)
#   D1 "Aracno" compare tra le applicazioni di COSMIC
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

A=/usr/local/bin/aracno
M=/usr/local/bin/aracno-menu
DESKTOP=/usr/local/share/applications/io.github.tommaso_palestini.AracnoMenu.desktop
MO=/usr/local/share/locale/en/LC_MESSAGES/aracno.mo
CUSTOM=$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom
LOG=$(mktemp); trap 'pkill -x aracno-menu 2>/dev/null || true; rm -f "$LOG"' EXIT

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
chiedi() { local r; read -r -p "  ? $1 [s/n] " r </dev/tty; [[ $r == s* || $r == S* ]]; }
vivo() { pgrep -x aracno-menu >/dev/null; }

echo ">> I1/I2: file installati e scorciatoia"
for f in "$M" "$DESKTOP" "$MO"; do [[ -e $f ]] && ok "$f" || fail "manca $f"; done
grep -qF 'Spawn("aracno-menu")' "$CUSTOM" 2>/dev/null \
  && ok "scorciatoia: $(grep -F 'Spawn("aracno-menu")' "$CUSTOM" | sed 's/^ *//')" \
  || fail "scorciatoia assente in $CUSTOM (lancia prototype/20-tasto-rapido.sh)"
(( fails == 0 )) || { echo "ESITO T11: FAIL (installazione incompleta)"; exit 1; }
"$A" hop debian >/dev/null

echo; echo ">> L1/L2: guarda il menù. Tra 2 s lo script passa ad arch e poi torna a debian da fuori."
pkill -x aracno-menu 2>/dev/null || true
"$M" >"$LOG" 2>&1 &
sleep 2;   "$A" hop arch >/dev/null
sleep 2.5; "$A" hop debian >/dev/null
sleep 1.5
echo "  (ora premi Esc nel menù)"
for _ in $(seq 600); do vivo || break; sleep 0.1; done
grep 'aggiornato in diretta' "$LOG" | sed 's/^aracno-menu: /    traccia: /'
grep -q 'aggiornato in diretta' "$LOG" && ok "aggiornamenti ricevuti" || fail "nessun aggiornamento in diretta nel log"
chiedi "L1: il menù si è aggiornato da solo (colore su arch, poi di nuovo su debian, e la scritta al centro)?" && ok "L1" || fail "L1"
chiedi "L2: i testi del menù erano in inglese (\"you are on debian\", \"active\", \"frozen\")?" && ok "L2" || fail "L2"

echo; echo ">> S1: premi Super+Shift+A (entro 30 s)"
for _ in $(seq 300); do vivo && break; sleep 0.1; done
if vivo; then
  ok "Super+Shift+A ha aperto il menù"
  echo "  ora premi di nuovo Super+Shift+A per chiuderlo (entro 30 s)"
  for _ in $(seq 300); do vivo || break; sleep 0.1; done
  vivo && fail "il menù è ancora aperto" || ok "Super+Shift+A l'ha chiuso"
else
  fail "il menù non si è aperto con Super+Shift+A"
fi

echo; echo ">> D1: apri la libreria delle applicazioni (Super+A) e cerca \"Aracno\""
chiedi "D1: c'è la voce \"Aracno\" e apre il menù?" && ok "D1" || fail "D1"
pkill -x aracno-menu 2>/dev/null || true

echo
if (( fails == 0 )); then
  echo "ESITO T11: PASS (aggiornamenti in diretta, traduzione, voce nelle applicazioni, Super+Shift+A)"
else
  echo "ESITO T11: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
