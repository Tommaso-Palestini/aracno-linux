#!/usr/bin/env bash
# Octopus prototipo — fase 4.1: rende visibile la GPU (/dev/dri) dentro ogni tentacolo.
# Scrive /etc/systemd/nspawn/NAME.nspawn, riavvia il tentacolo e verifica.
# Nota: riavviare un tentacolo lo spegne; i processi in esecuzione si perdono.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

M=/var/lib/machines
O="$(dirname "$0")/octo"
CONF=/etc/systemd/nspawn

names() { for d in "$M"/*/; do [[ -d $d/etc ]] && basename "$d"; done; }

echo ">> Dispositivi GPU sull'host"
ls -l /dev/dri

for n in $(names); do
  cat > "$CONF/$n.nspawn" <<EOF
# Generato da prototype/04-gpu-bind.sh — GPU condivisa con il tentacolo
# Le prime sezioni devono restare uguali a prototype/01-create-tentacles.sh:
# VirtualEthernet=no fa condividere la rete dell'host (senza, il container resta isolato e offline).
[Exec]
Boot=yes
PrivateUsers=no

[Network]
VirtualEthernet=no

[Files]
Bind=/dev/dri
EOF
  # DeviceAllow nel file .nspawn non viene applicato: la unit ha DevicePolicy=closed
  # e serve un drop-in della unit per permettere l'accesso ai device GPU.
  mkdir -p "/etc/systemd/system/systemd-nspawn@$n.service.d"
  cat > "/etc/systemd/system/systemd-nspawn@$n.service.d/gpu.conf" <<EOF
# Generato da prototype/04-gpu-bind.sh — permette alla GPU di essere aperta dal tentacolo
[Service]
DeviceAllow=/dev/dri/card0 rw
DeviceAllow=/dev/dri/renderD128 rw
EOF
  echo "scritto $CONF/$n.nspawn e drop-in GPU"
done
systemctl daemon-reload

echo; echo ">> Riavvio dei tentacoli per applicare la configurazione"
for n in $(names); do
  if systemctl is-active -q "systemd-nspawn@$n.service"; then
    machinectl poweroff "$n" >/dev/null
    sleep 2
  fi
  "$O" start "$n"
done

echo; echo ">> Verifica: /dev/dri visibile dentro ogni tentacolo"
FAIL=0
for n in $(names); do
  if systemd-run -M "$n" --quiet --wait --collect /bin/ls /dev/dri >/dev/null 2>&1 \
     && systemd-run -M "$n" --quiet --wait --collect /bin/test -c /dev/dri/renderD128 2>/dev/null; then
    echo "  $n: OK"
  else
    echo "  $n: FAIL"
    FAIL=$((FAIL + 1))
  fi
done

echo
if (( FAIL == 0 )); then
  echo "ESITO 4.1: PASS (GPU visibile in tutti i tentacoli)"
else
  echo "ESITO 4.1: FAIL ($FAIL tentacoli senza GPU). Incolla l'output completo."
  exit 1
fi
