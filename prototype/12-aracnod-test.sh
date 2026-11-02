#!/usr/bin/env bash
# Aracno prototipo — T6: verifica Switch di aracnod.
# Va lanciato SENZA sudo, dalla sessione grafica: è il caso reale (switch senza password).
# Usa sudo solo per la prova con "nobody" (O3): chiede la password.
# Prima: reinstallare aracnod con prototype/11-install-aracnod.sh (lo script controlla che sia aggiornato).
#
# Ipotesi e criteri (scritti prima del test):
#   O2  20 switch alternati arch/debian dalla sessione attiva, senza password: tutti riusciti,
#       mediana del tempo misurato da aracnod < 150 ms; alla fine il tentacolo scelto è l'unico attivo
#   O2b durante uno switch aracnod emette StateChanged; il journal registra lo switch con l'uid del chiamante
#   O3  Switch chiamato come nobody da un servizio (fuori da ogni sessione): NotAuthorized, stato invariato
#       (correzione dopo il primo giro: `sudo runuser -u nobody` dal terminale resta DENTRO la sessione
#       attiva e polkit, con allow_active, guarda la sessione del processo, non l'utente)
#   O4  nomi non validi ("../etc", "Debian", "a b", "") → InvalidName; "fedora" (inesistente) → NotFound
#   O5  30 giri di due Switch lanciati nello stesso istante (arch e debian): ogni chiamata riesce o
#       riceve Busy (nessun altro errore), almeno un Busy in tutto, dopo ogni giro un solo tentacolo attivo
#       (correzione dopo il primo giro: l'avvio di un tentacolo spento dura ~100 ms, troppo poco per
#       sovrapporre due switch lanciati a 0,2 s di distanza)
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
NAME=io.github.tommaso_palestini.Aracno1
OPATH=/io/github/tommaso_palestini/Aracno1
N=${N:-20}
SOGLIA_MS=150

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }

call()   { gdbus call --system --dest "$NAME" --object-path "$OPATH" --method "$NAME.Manager.$1" "${@:2}"; }
switch() { call Switch "$1"; }
ms_of()  { sed -n 's/^(uint32 \([0-9]*\),)$/\1/p'; }
# stati come "nome=stato" ordinati, da ListTentacles
stati()  { busctl call --system --json=short "$NAME" "$OPATH" "$NAME.Manager" ListTentacles \
           | python3 -c 'import sys,json; print(" ".join(f"{r[0]}={r[1]}" for r in json.load(sys.stdin)["data"][0]))'; }
stato_di() { stati | tr ' ' '\n' | sed -n "s/^$1=//p"; }
attesa_errore() {  # attesa_errore NOME_ERRORE DESCRIZIONE ARGOMENTI_SWITCH...
  local err=$1 d=$2 out; shift 2
  if out=$(switch "$@" 2>&1); then fail "$d: riuscito (atteso $err)"
  elif grep -q "Error\.$err" <<<"$out"; then ok "$d → $err"
  else fail "$d: errore diverso da $err: $out"; fi
}

echo ">> Controllo: aracnod installato è quello compilato"
inst=$(sha256sum /usr/local/libexec/aracnod 2>/dev/null | cut -c1-64 || true)
comp=$(sha256sum "$R/aracno/target/release/aracnod" | cut -c1-64)
[[ $inst == "$comp" ]] || { echo "  aracnod installato non aggiornato: lancia prima"; \
  echo "  sudo $R/prototype/11-install-aracnod.sh"; exit 1; }
echo "  ok ($(cut -c1-16 <<<"$comp")…)"
T0=$(date '+%Y-%m-%d %H:%M:%S')
echo "  stati iniziali: $(stati)"

echo; echo ">> O2: $N switch dalla sessione attiva"
tempi=()
for i in $(seq "$N"); do
  t=$([[ $((i % 2)) -eq 1 ]] && echo arch || echo debian)
  if out=$(switch "$t" 2>&1); then tempi+=("$(ms_of <<<"$out")")
  else fail "switch $i → $t: $out"; break; fi
done
if (( ${#tempi[@]} == N )); then
  ordinati=($(printf '%s\n' "${tempi[@]}" | sort -n))
  med=${ordinati[$((N / 2))]}
  echo "  tempi (ms): ${tempi[*]}"
  (( med < SOGLIA_MS )) && ok "mediana $med ms (soglia $SOGLIA_MS)" || fail "mediana $med ms ≥ $SOGLIA_MS"
fi
ultimo=$([[ $((N % 2)) -eq 1 ]] && echo arch || echo debian)
attivi=$(stati | tr ' ' '\n' | grep -c '=active$' || true)
[[ $(stato_di "$ultimo") == active && $attivi == 1 ]] && ok "$ultimo unica attiva ($(stati))" || fail "stati finali: $(stati)"

echo; echo ">> O2b: segnale StateChanged e journal"
mon=$(mktemp)
gdbus monitor --system --dest "$NAME" >"$mon" 2>&1 & mpid=$!
sleep 0.5
switch arch >/dev/null
sleep 0.5
kill "$mpid" 2>/dev/null || true; wait "$mpid" 2>/dev/null || true
grep -q "StateChanged" "$mon" && ok "StateChanged ricevuto: $(grep -m1 StateChanged "$mon" | sed 's/.*StateChanged//')" || fail "nessun StateChanged: $(cat "$mon")"
rm -f "$mon"
log=$(journalctl -u aracnod.service --since "$T0" --no-pager -o cat | grep -E "switch (→ )?arch \(uid $(id -u)\): ok" | tail -1 || true)
[[ -n $log ]] && ok "journal: $log" || fail "nel journal manca lo switch con uid $(id -u)"

echo; echo ">> O3: switch come nobody da un servizio, fuori da ogni sessione (chiede la password di sudo)"
switch arch >/dev/null   # parto da arch attiva: nobody prova a passare a debian
prima=$(stati)
if out=$(sudo systemd-run --quiet --wait --pipe --collect --uid=nobody --gid=nogroup \
           gdbus call --system --dest "$NAME" --object-path "$OPATH" \
           --method "$NAME.Manager.Switch" debian 2>&1); then fail "nobody: switch riuscito"
elif grep -q "Error\.NotAuthorized" <<<"$out"; then ok "nobody → NotAuthorized"
else fail "nobody: errore inatteso: $out"; fi
[[ $(stati) == "$prima" ]] && ok "stato invariato ($prima)" || fail "stato cambiato: $prima → $(stati)"

echo; echo ">> O4: nomi non validi e inesistenti"
for n in "../etc" "Debian" "a b" ""; do attesa_errore InvalidName "\"$n\"" "$n"; done
attesa_errore NotFound '"fedora"' fedora

echo; echo ">> O5: 30 giri di due switch lanciati nello stesso istante"
busy=0; altri=0; incoerenti=0
d=$(mktemp -d)
for i in $(seq 30); do
  switch arch   >"$d/a" 2>&1 & pa=$!
  switch debian >"$d/b" 2>&1 & pb=$!
  wait "$pa" "$pb" || true
  for f in "$d/a" "$d/b"; do
    if grep -q '^(uint32' "$f"; then :
    elif grep -q 'Error\.Busy' "$f"; then busy=$((busy + 1))
    else altri=$((altri + 1)); echo "  errore inatteso al giro $i: $(cat "$f")"; fi
  done
  attivi=$(stati | tr ' ' '\n' | grep -c '=active$' || true)
  [[ $attivi == 1 ]] || { incoerenti=$((incoerenti + 1)); echo "  giro $i: $(stati)"; }
done
rm -rf "$d"
echo "  Busy: $busy su 60 chiamate; altri errori: $altri; giri con stato incoerente: $incoerenti"
(( altri == 0 ))      && ok "solo successi o Busy"           || fail "$altri errori diversi da Busy"
(( busy > 0 ))        && ok "Busy osservato ($busy volte)"   || fail "nessun Busy: la sovrapposizione non è dimostrata"
(( incoerenti == 0 )) && ok "un solo tentacolo attivo dopo ogni giro" || fail "$incoerenti giri con più o nessun attivo"

echo; echo ">> Ripristino: debian attiva"
switch debian >/dev/null && echo "  $(stati)"

echo
if (( fails == 0 )); then
  echo "ESITO T6: PASS (Switch senza password dalla sessione, rifiuti corretti, Busy, segnale e journal)"
else
  echo "ESITO T6: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
