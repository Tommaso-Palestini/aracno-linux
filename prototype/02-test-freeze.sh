#!/usr/bin/env bash
# Aracno prototipo — fase 2: verifica che lo switch dia "piena potenza" al tentacolo attivo.
# Mette un carico CPU in entrambi i tentacoli, poi fa switch e misura.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
O="$(dirname "$0")/aracno"

for n in debian arch; do "$O" start "$n"; done

echo ">> Carico CPU (1 core) in entrambi i tentacoli"
for n in debian arch; do
  systemd-run -M "$n" --unit=aracno-burn --quiet /bin/sh -c 'while :; do :; done'
done
sleep 1
"$O" cpu debian; "$O" cpu arch

echo; echo ">> switch → debian"; "$O" switch debian
"$O" cpu debian; "$O" cpu arch
"$O" list

echo; echo ">> switch → arch"; "$O" switch arch
"$O" cpu debian; "$O" cpu arch

echo; echo ">> Il processo di debian è sopravvissuto al congelamento?"
"$O" switch debian >/dev/null
systemctl -M debian is-active aracno-burn && echo "sì: ripreso esattamente da dove era"

echo; echo ">> Pulizia"
for n in debian arch; do
  "$O" thaw "$n" 2>/dev/null || true
  systemctl -M "$n" stop aracno-burn 2>/dev/null || true
done
"$O" list
echo "Tentacoli lasciati accesi. Spegni con: sudo ./aracno stop debian ; sudo ./aracno stop arch"
