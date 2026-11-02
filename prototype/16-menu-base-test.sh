#!/usr/bin/env bash
# Aracno prototipo — T8: menù base (aracno-menu). Test guidato: lo script apre il menù,
# tu guardi lo schermo e rispondi s/n. Va lanciato SENZA sudo, dalla sessione grafica.
# Prima compila:
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno && \
#   PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig cargo build --release -p aracno-menu
#
# Ipotesi e criteri (scritti prima del test):
#   B1 primo avvio: il menù copre tutto lo schermo (pannelli compresi), modo layer-shell,
#      mostra debian e arch con simbolo, stato in testo e RAM, il filo attivo per primo
#   B2 avvio a freddo: tempo dalla richiesta alla finestra visibile (solo misura, T2: 129–207 ms)
#   B3 secondo avvio di aracno-menu con il menù aperto: il menù si chiude, il processo resta
#   B4 terzo avvio: il menù si riapre in < 200 ms (M1, processo già caldo)
#   B5 Esc chiude il menù, il processo resta
#   M4 bus di sistema irraggiungibile: messaggio d'errore chiaro con ⚠, nessun crash, Esc chiude
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
tempi() { grep -o 'visibile in [0-9]* ms ([^)]*)' "$LOG" || true; }
vivo()  { pgrep -f "^$M" >/dev/null; }

pkill -f "^$M" 2>/dev/null || true; sleep 0.3
"$R/prototype/aracno" list 2>/dev/null | sed 's/^/    /' || true

echo; echo ">> B1/B2: primo avvio: guarda il menù, premi Esc per chiuderlo, poi rispondi qui"
"$M" >>"$LOG" 2>&1 &
sleep 2
t=$(tempi | tail -1); echo "    $t"
[[ $t == *layer-shell* ]] && ok "modo layer-shell" || fail "modo: ${t:-nessun log}"
chiedi "Hai visto il menù a tutto schermo con debian (attivo, per primo) e arch, con simbolo, stato e RAM?" \
  && ok "B1 contenuto" || fail "B1 contenuto"
echo "  B2 (misura): ${t:-?}"
chiedi "Esc ha chiuso il menù (e il terminale ha ripreso la tastiera)?" && ok "B5 Esc chiude" || fail "B5 Esc"
vivo && ok "processo ancora vivo dopo Esc" || fail "il processo è uscito con Esc"

echo; echo ">> B3/B4: il tasto rapido apre e chiude (lo simula un nuovo avvio)"
t_tasto=$(date +%s%3N); "$M"; sleep 1
t=$(grep -o 'visibile in [0-9]* ms ([^)]*) @[0-9]*' "$LOG" | tail -1); echo "    $t"
visto=${t##*@}
ms=$(( ${visto:-0} - t_tasto ))
[[ -n $visto ]] && (( ms >= 0 && ms < 200 )) && ok "B4 dal tasto alla finestra: $ms ms (< 200)" || fail "B4 dal tasto alla finestra: $ms ms (${t:-nessun log})"
"$M"; sleep 1
chiedi "Il secondo avvio ha chiuso il menù?" && ok "B3 si chiude" || fail "B3"
vivo && ok "processo ancora vivo" || fail "il processo è uscito"

echo; echo ">> M4: bus di sistema irraggiungibile: leggi il messaggio, premi Esc, poi rispondi qui"
pkill -f "^$M"; sleep 0.5
DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent "$M" >>"$LOG" 2>&1 &
sleep 2
chiedi "Il menù mostra un messaggio d'errore chiaro con ⚠ invece dei fili?" && ok "M4 messaggio" || fail "M4 messaggio"
vivo && ok "nessun crash" || fail "aracno-menu è uscito (crash?)"
grep -iE 'panic|CRITICAL' "$LOG" && fail "panic o CRITICAL nel log" || ok "log pulito"

echo
if (( fails == 0 )); then
  echo "ESITO T8: PASS (menù base: layer-shell, elenco, apri/chiudi, Esc, errore chiaro)"
else
  echo "ESITO T8: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
