#!/usr/bin/env bash
# Octopus prototipo — fase 4.4: rende visibile al tentacolo il socket Wayland dell'utente.
# Monta SOLO il socket (non D-Bus, non PulseAudio): il container può disegnare finestre
# sul desktop, ma non accede al resto della sessione. Compromesso da tenere presente.
# Aggiunge una riga Bind= al file .nspawn di ogni tentacolo e li riavvia.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

M=/var/lib/machines
O="$(dirname "$0")/octo"
CONF=/etc/systemd/nspawn
UTENTE=${UTENTE:-xenon}
UID_UTENTE=$(id -u "$UTENTE")
SOCK="/run/user/$UID_UTENTE/wayland-1"

[[ -S $SOCK ]] || { echo "Socket Wayland non trovato: $SOCK (la sessione grafica è attiva?)"; exit 1; }
echo ">> Socket host: $SOCK"

names() { for d in "$M"/*/; do [[ -d $d/etc ]] && basename "$d"; done; }

for n in $(names); do
  f="$CONF/$n.nspawn"
  if grep -q "octo-wayland/wayland-1" "$f"; then
    echo "  $n: bind già presente"
  else
    printf 'Bind=%s:/run/octo-wayland/wayland-1\n' "$SOCK" >> "$f"
    echo "  $n: bind aggiunto"
  fi
done

echo; echo ">> Riavvio dei tentacoli"
for n in $(names); do
  if systemctl is-active -q "systemd-nspawn@$n.service"; then
    machinectl poweroff "$n" >/dev/null
    sleep 2
  fi
  "$O" start "$n"
done

echo; echo ">> Verifica: socket visibile dentro ogni tentacolo"
FAIL=0
for n in $(names); do
  if systemd-run -M "$n" --quiet --wait --pipe /bin/sh -c 'test -S /run/octo-wayland/wayland-1' >/dev/null 2>&1; then
    echo "  $n: OK"
  else
    echo "  $n: FAIL"
    FAIL=$((FAIL + 1))
  fi
done

echo
if (( FAIL == 0 )); then
  echo "ESITO 4.4 (bind): PASS. Prossimo passo: aprire una finestra, vedi le istruzioni."
else
  echo "ESITO 4.4 (bind): FAIL ($FAIL tentacoli)."
  exit 1
fi
