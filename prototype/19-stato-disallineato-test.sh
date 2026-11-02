#!/usr/bin/env bash
# Aracno prototipo — systemd e kernel non d'accordo sul congelamento di un filo.
# Bug visto il 2026-11-02: debian, congelato, è morto (watchdog); al riavvio systemd 255
# diceva ancora FreezerState=frozen mentre il kernel non lo era (cgroup.freeze=0).
# Il menù mostrava lo stato sbagliato e uno switch avrebbe lasciato due fili accesi.
# Correzione in aracnod: lo stato si legge anche dal kernel (cgroup.events) e prima di
# switch e stop systemd viene riallineato.
# Si lancia con sudo, DOPO aver reinstallato aracnod (11-install-aracnod.sh).
#
# Ipotesi e criteri (scritti prima del test):
#   K1 aracnod legge cgroup.events dentro la sua sandbox: con i fili d'accordo,
#      ListStrands coincide con il kernel per debian e arch
#   K2 riproduzione: arch congelato viene ucciso (SIGKILL) e riavviato; systemd dice
#      frozen, il kernel no (se non si riproduce, il test lo dice e salta K3–K4)
#   K3 ListStrands dice arch "active" (vale il kernel)
#   K4 `aracno hop debian`: il journal di aracnod dice "riallineo a active" per arch;
#      dopo, systemd e kernel coincidono per entrambi e c'è un solo filo attivo (debian)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
UTENTE=${SUDO_USER:-xenon}
A=/usr/local/bin/aracno
NAME=io.github.tommaso_palestini.Aracno1
OPATH=/io/github/tommaso_palestini/Aracno1

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
u()    { echo "systemd-nspawn@$1.service"; }
kernel() {  # active|frozen|off secondo il kernel
  local e=/sys/fs/cgroup/machine.slice/$(u "$1")/cgroup.events
  [[ -r $e ]] || { echo off; return; }
  grep -q '^frozen 1' "$e" && echo frozen || echo active
}
sd() {  # active|frozen|off secondo systemd
  systemctl is-active -q "$(u "$1")" || { echo off; return; }
  [[ $(systemctl show -P FreezerState "$(u "$1")") == frozen ]] && echo frozen || echo active
}
api() {  # stato secondo aracnod (ListStrands, chiamato dall'utente)
  runuser -u "$UTENTE" -- busctl call --system --json=short "$NAME" "$OPATH" "$NAME.Manager" ListStrands \
    | python3 -c 'import sys,json; [print(r[1]) for r in json.load(sys.stdin)["data"][0] if r[0]==sys.argv[1]]' "$1"
}
hop() { runuser -u "$UTENTE" -- "$A" hop "$1"; }
pronto() {
  for _ in $(seq 60); do
    s=$(systemctl -M "$1" is-system-running 2>/dev/null || true)
    [[ $s == running || $s == degraded ]] && return 0; sleep 0.5
  done; return 1
}

echo ">> Preparazione: debian attiva, arch congelata"
hop debian >/dev/null
for n in debian arch; do echo "    $n: systemd $(sd $n), kernel $(kernel $n), aracnod $(api $n)"; done

echo; echo ">> K1: aracnod legge il kernel dalla sua sandbox"
for n in debian arch; do
  [[ $(api $n) == "$(kernel $n)" ]] && ok "$n: aracnod $(api $n) = kernel" || fail "$n: aracnod $(api $n), kernel $(kernel $n)"
done
T0=$(date '+%Y-%m-%d %H:%M:%S')

echo; echo ">> K2: arch congelato ucciso e riavviato"
systemctl kill --signal=SIGKILL "$(u arch)" || true
for _ in $(seq 40); do systemctl is-active -q "$(u arch)" || break; sleep 0.25; done
systemctl reset-failed "$(u arch)" 2>/dev/null || true
systemctl start "$(u arch)"; pronto arch || true
echo "    arch: systemd $(sd arch), kernel $(kernel arch)"
if [[ $(sd arch) == frozen && $(kernel arch) == active ]]; then
  ok "disallineamento riprodotto (systemd frozen, kernel no)"
  riprodotto=1
else
  echo "  NOTA: disallineamento non riprodotto in questo modo; K3–K4 saltati"
  riprodotto=0
fi

if (( riprodotto )); then
  echo; echo ">> K3: ListStrands segue il kernel"
  [[ $(api arch) == active ]] && ok "aracnod dice arch active" || fail "aracnod dice arch $(api arch)"

  echo; echo ">> K4: switch a debian con riallineamento"
  hop debian | sed 's/^/    /'
  journalctl -u aracnod.service --since "$T0" --no-pager -o cat | grep -q 'arch: systemd e kernel non coincidono, riallineo a active' \
    && ok "journal: riallineo arch a active" || fail "nel journal manca il riallineamento"
  for n in debian arch; do
    [[ $(sd $n) == "$(kernel $n)" ]] && ok "$n: systemd $(sd $n) = kernel" || fail "$n: systemd $(sd $n), kernel $(kernel $n)"
  done
  attivi=0; for n in debian arch; do [[ $(kernel $n) == active ]] && attivi=$((attivi + 1)); done
  [[ $(kernel debian) == active && $attivi == 1 ]] && ok "un solo filo attivo: debian" || fail "attivi: $attivi (debian $(kernel debian), arch $(kernel arch))"
fi

echo; echo ">> Ripristino: debian attiva, arch congelata"
hop debian >/dev/null || true
for n in debian arch; do echo "    $n: systemd $(sd $n), kernel $(kernel $n)"; done

echo
if (( fails == 0 )); then
  echo "ESITO: PASS (aracnod segue il kernel e riallinea systemd prima dello switch)"
else
  echo "ESITO: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
