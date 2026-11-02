#!/usr/bin/env bash
# Aracno prototipo — fase 4.6: verifica `aracno upgrade`.
#
# Ipotesi e criteri (scritti prima del test):
#   U1  Con debian attiva e arch congelata, `aracno upgrade` aggiorna entrambe ed esce con 0.
#       Dopo: debian ancora attiva, arch ancora congelata (lo stato di prima è rimesso).
#   U2  Dopo l'aggiornamento non restano pacchetti da aggiornare:
#       debian `apt list --upgradable` vuoto, arch `pacman -Qu` vuoto.
#   U3  Un tentacolo spento viene avviato, aggiornato e rispento.
#   U4  Un nome inesistente fa uscire con errore, senza toccare gli altri tentacoli.
# Il tempo di ogni aggiornamento viene stampato da aracno (solo misura, senza soglia).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

O="$(dirname "$0")/aracno"
A=debian
B=arch
fails=0
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
state_of() { "$O" list | awk -v n="$1" '$1 == n {print $2}'; }
inside()   { systemd-run -M "$1" --quiet --wait --pipe --collect /bin/sh -c "$2" 2>/dev/null; }

echo ">> Preparazione: $A attiva, $B congelata"
for n in $A $B; do [[ $(state_of "$n") != spenta ]] || "$O" start "$n"; done
"$O" switch "$A" >/dev/null
"$O" list | sed 's/^/  /'

echo; echo ">> U1: aracno upgrade (tutti)"
if "$O" upgrade; then echo "  uscita 0"; else fail "aracno upgrade è uscito con errore"; fi
[[ $(state_of "$A") == attiva ]]    || fail "$A non è più attiva ($(state_of "$A"))"
[[ $(state_of "$B") == congelata ]] || fail "$B non è più congelata ($(state_of "$B"))"
"$O" list | sed 's/^/  /'

echo; echo ">> U2: nessun pacchetto ancora da aggiornare"
na=$(inside "$A" 'apt list --upgradable 2>/dev/null | grep -c upgradable || true')
echo "  $A: ${na:-?} pacchetti da aggiornare"
[[ $na == 0 ]] || fail "$A ha ancora pacchetti da aggiornare"
"$O" switch "$B" >/dev/null
nb=$(inside "$B" 'pacman -Qu 2>/dev/null | wc -l')
echo "  $B: ${nb:-?} pacchetti da aggiornare"
[[ $nb == 0 ]] || fail "$B ha ancora pacchetti da aggiornare"
"$O" switch "$A" >/dev/null

echo; echo ">> U3: tentacolo spento"
"$O" stop "$B" >/dev/null
for _ in $(seq 20); do [[ $(state_of "$B") == spenta ]] && break; sleep 0.5; done
[[ $(state_of "$B") == spenta ]] || fail "$B non si è spenta per il test"
if "$O" upgrade "$B"; then echo "  uscita 0"; else fail "aracno upgrade $B è uscito con errore"; fi
for _ in $(seq 20); do [[ $(state_of "$B") == spenta ]] && break; sleep 0.5; done
[[ $(state_of "$B") == spenta ]] || fail "$B non è stata rispenta ($(state_of "$B"))"

echo; echo ">> U4: nome inesistente"
if "$O" upgrade nonesiste; then fail "nessun errore per un tentacolo inesistente"; else echo "  errore come atteso"; fi
[[ $(state_of "$A") == attiva ]] || fail "$A cambiata dal tentativo con nome inesistente"

echo; echo ">> Ripristino: $B riaccesa e congelata"
"$O" start "$B" >/dev/null; "$O" switch "$A" >/dev/null
"$O" list | sed 's/^/  /'

echo
if (( fails == 0 )); then
  echo "ESITO 4.6: PASS (aracno upgrade aggiorna e rimette lo stato di ogni tentacolo)"
else
  echo "ESITO 4.6: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
