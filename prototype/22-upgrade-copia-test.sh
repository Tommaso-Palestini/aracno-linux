#!/usr/bin/env bash
# Aracno prototipo — T12: copia di sicurezza prima di `aracno upgrade`, e ripristino.
# Si lancia con sudo. Serve la rete (aggiorna debian davvero). Durata: qualche minuto.
#
# Ipotesi e criteri (scritti prima del test):
#   U1 spazio insufficiente (simulato con ARACNO_PROVA_LIBERI=1): upgrade rifiutato con un
#      messaggio chiaro, codice ≠ 0, nessuna copia e nessun aggiornamento
#   U2 `aracno upgrade debian` con debian attivo: prima la copia (tempo misurato, ci si
#      aspetta pochi secondi su SSD), poi l'aggiornamento; debian di nuovo attivo
#   U3 la copia ha la stessa dimensione del filo (±1%) e `aracno copie` la elenca con la data
#   U4 un file scritto nel filo dopo la copia sparisce con `aracno ripristina debian`; la
#      versione tolta (con il file) resta in .scartata; debian torna attivo, aracnod lo vede
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
M=/var/lib/machines
COPIE=/var/lib/aracno/copie
UTENTE=${SUDO_USER:-xenon}
MARCA=root/aracno-marcatore-t12

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
stato() { "$O" list | awk -v n="$1" '$1 == n {print $2}'; }
byte() { du -sb --one-file-system "$1" | cut -f1; }

runuser -u "$UTENTE" -- /usr/local/bin/aracno hop debian >/dev/null
echo "    debian: $(stato debian), $(( $(byte $M/debian) / 1048576 )) MiB"

echo; echo ">> U1: spazio insufficiente (simulato)"
prima=$(ls -d "$COPIE"/debian 2>/dev/null || true)
set +e; out=$(ARACNO_PROVA_LIBERI=1 "$O" upgrade debian 2>&1); rc=$?; set -e
echo "$out" | sed 's/^/    /'
(( rc != 0 )) && grep -q 'spazio insufficiente' <<<"$out" && ok "rifiutato (codice $rc)" || fail "non rifiutato (codice $rc)"
[[ $(ls -d "$COPIE"/debian 2>/dev/null || true) == "$prima" ]] && ! ls -d "$COPIE"/.debian.nuova >/dev/null 2>&1 \
  && ok "nessuna copia creata" || fail "è comparsa una copia"
grep -q 'aggiornato in' <<<"$out" && fail "ha aggiornato comunque" || ok "nessun aggiornamento"

echo; echo ">> U2: upgrade con copia"
out=$("$O" upgrade debian 2>&1) || true
echo "$out" | grep -E 'copia|aggiornat|FALLIT|>>' | sed 's/^/    /'
grep -q 'debian: copia di sicurezza' <<<"$out" && ok "copia fatta: $(grep -o 'in [0-9]* ms' <<<"$out" | head -1)" || fail "nessuna copia"
grep -q 'debian: aggiornato in' <<<"$out" && ok "aggiornamento riuscito" || fail "aggiornamento non riuscito"
[[ $(stato debian) == attiva ]] && ok "debian di nuovo attivo" || fail "debian: $(stato debian)"

echo; echo ">> U3: la copia"
a=$(byte $M/debian); c=$(byte $COPIE/debian)
echo "    filo $(( a / 1048576 )) MiB, copia $(( c / 1048576 )) MiB"
d=$(( a > c ? a - c : c - a ))
# l'upgrade dopo la copia può cambiare il filo: tolleranza 1% o 64 MiB
(( d * 100 <= a || d <= 67108864 )) && ok "dimensioni coerenti" || fail "differenza di $(( d / 1048576 )) MiB"
"$O" copie | sed 's/^/    /'
"$O" copie | grep -qE '^debian +[0-9]{4}-' && ok "aracno copie elenca debian con la data" || fail "aracno copie non elenca debian"

echo; echo ">> U4: ripristino"
echo "scritto dopo la copia, $(date)" >"$M/$MARCA"
"$O" ripristina debian | sed 's/^/    /'
[[ ! -e $M/$MARCA ]] && ok "il file scritto dopo la copia è sparito" || fail "il file c'è ancora"
[[ -e $COPIE/debian.scartata/$MARCA ]] && ok "la versione tolta è in .scartata" || fail "manca .scartata con il file"
[[ $(stato debian) == attiva ]] && ok "debian di nuovo attivo" || fail "debian: $(stato debian)"
w=$(runuser -u "$UTENTE" -- /usr/local/bin/aracno where 2>&1 || true)
[[ $w == debian ]] && ok "aracnod: sei su debian" || fail "aracnod dice: $w"

echo
if (( fails == 0 )); then
  echo "ESITO T12: PASS (copia prima dell'upgrade, controllo dello spazio, ripristino)"
else
  echo "ESITO T12: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
