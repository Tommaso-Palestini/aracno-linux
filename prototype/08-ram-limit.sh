#!/usr/bin/env bash
# Aracno prototipo — fase 4.5: verifica `aracno limit` (tetto RAM per tentacolo).
#
# Perché: il congelamento libera solo la CPU, non la RAM (ADR-0002). Con 5,7 GB
# serve un modo per togliere RAM a un tentacolo, soprattutto quando è congelato.
#
# Ipotesi e criteri (scritti prima del test):
#   T1  `aracno limit debian 512M` scrive memory.max = 536870912 e `aracno list` lo mostra;
#       `aracno limit debian infinity` lo riporta a "max".
#   T2  Con un tetto di 512M, un processo che riempie 768 MB NON viene ucciso:
#       il kernel manda in swap l'eccesso. Attese: memhog "ok", swap del
#       tentacolo >= 200 MB, nessun oom_kill, tentacolo ancora attivo.
#   T3  Il caso d'uso vero: tentacolo congelato con 768 MB occupati, si abbassa
#       il tetto a 256M. Attese: memory.current <= 256M senza oom_kill, tempo
#       misurato; allo switch di ritorno il processo è vivo e i dati sono
#       intatti (verify ok). Solo misura, senza soglia: quanta RAM l'host
#       recupera davvero, dato che lo swap principale è zram (compresso, ma in RAM).
#
# Usa i tentacoli debian (alloca) e arch (destinazione dello switch).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

O="$(dirname "$0")/aracno"
SRC="$(dirname "$0")/memhog.c"
A=debian
B=arch
M=/var/lib/machines
CG=/sys/fs/cgroup/machine.slice/systemd-nspawn@$A.service
LOG=$M/$A/var/tmp/memhog.log

mb()        { awk '{printf "%d", $1/1048576}' "$1"; }
cur()       { mb "$CG/memory.current"; }
swp()       { mb "$CG/memory.swap.current"; }
ooms()      { awk '/^oom_kill /{print $2}' "$CG/memory.events"; }
avail()     { awk '/^MemAvailable/{printf "%d", $2/1024}' /proc/meminfo; }
zram()      { [[ -r /sys/block/zram0/mm_stat ]] && awk '{printf "zram: %d MB di dati in %d MB di RAM", $1/1048576, $3/1048576}' /sys/block/zram0/mm_stat || echo "zram: assente"; }
inside()    { systemd-run -M "$1" --quiet --wait --pipe /bin/sh -c "$2" 2>&1; }
wait_log()  { for _ in $(seq "${2:-120}"); do grep -q -E "$1" "$LOG" 2>/dev/null && return 0; sleep 0.5; done; return 1; }
stop_hog()  { systemctl -M "$A" stop aracno-mem 2>/dev/null || true; systemctl -M "$A" reset-failed aracno-mem 2>/dev/null || true; }
start_hog() {
  stop_hog; rm -f "$LOG"
  systemd-run -M "$A" --unit=aracno-mem --collect --quiet /bin/sh -c "exec /var/tmp/memhog $1 > /var/tmp/memhog.log 2>&1"
}

fails=0
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }

cleanup() {
  "$O" switch "$A" >/dev/null 2>&1 || true
  stop_hog
  "$O" limit "$A" infinity >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ">> Preparazione"
for n in $A $B; do
  systemctl is-active -q "systemd-nspawn@$n.service" || "$O" start "$n"
done
"$O" switch "$A" >/dev/null
install -m 644 "$SRC" "$M/$A/var/tmp/memhog.c"
inside "$A" 'gcc -O2 -o /var/tmp/memhog /var/tmp/memhog.c' \
  || { echo "Compilazione fallita. Installa gcc: ! sudo machinectl shell $A /bin/sh -c 'apt-get install -y gcc'"; exit 1; }
echo "  swap host:"; tail -n +2 /proc/swaps | awk '{printf "    %s %s, %d MB\n", $1, $2, $3/1024}'
echo "  memory.swap.max di $A: $(cat "$CG/memory.swap.max")"

echo; echo ">> T1: il tetto viene applicato"
"$O" limit "$A" 512M
v=$(cat "$CG/memory.max"); echo "  memory.max = $v"
[[ $v == 536870912 ]] || fail "memory.max atteso 536870912"
"$O" list | sed 's/^/  /'
"$O" limit "$A" infinity >/dev/null
v=$(cat "$CG/memory.max"); echo "  dopo infinity: memory.max = $v"
[[ $v == max ]] || fail "memory.max atteso max"

echo; echo ">> T2: tetto 512M, il processo riempie 768 MB"
"$O" limit "$A" 512M >/dev/null
o0=$(ooms)
start_hog 768
if wait_log '^(ok:|ERRORE)'; then cat "$LOG" | sed 's/^/  memhog: /'; else echo "  memhog: nessuna risposta in 60 s"; fi
echo "  RAM tentacolo: $(cur) MB, swap tentacolo: $(swp) MB, oom_kill: $(( $(ooms) - o0 ))"
grep -q '^ok:' "$LOG" 2>/dev/null || fail "memhog non ha finito il riempimento"
(( $(swp) >= 200 ))              || fail "swap del tentacolo sotto 200 MB"
(( $(ooms) == o0 ))              || fail "il kernel ha ucciso processi (oom_kill)"
systemctl is-active -q "systemd-nspawn@$A.service" || fail "il tentacolo $A si è spento"
stop_hog
"$O" limit "$A" infinity >/dev/null

echo; echo ">> T3: tetto abbassato su un tentacolo congelato"
start_hog 768
wait_log '^(ok:|ERRORE)' || true
grep -q '^ok:' "$LOG" 2>/dev/null || { fail "memhog senza tetto non ha finito"; exit 1; }
out=$("$O" switch "$B"); echo "  $out" | tail -1
c0=$(cur); a0=$(avail); o0=$(ooms)
echo "  prima:  RAM $A $c0 MB, swap $A $(swp) MB, MemAvailable host $a0 MB, $(zram)"
t0=$(date +%s%N)
"$O" limit "$A" 256M >/dev/null
ms_lim=$(( ($(date +%s%N) - t0) / 1000000 ))
sleep 1
c1=$(cur); a1=$(avail)
echo "  dopo:   RAM $A $c1 MB, swap $A $(swp) MB, MemAvailable host $a1 MB, $(zram)"
echo "  tetto applicato in $ms_lim ms; RAM tolta al tentacolo: $((c0 - c1)) MB; RAM guadagnata dall'host: $((a1 - a0)) MB"
(( c1 <= 256 ))     || fail "RAM del tentacolo congelato sopra 256 MB"
(( $(ooms) == o0 )) || fail "oom_kill durante l'abbassamento del tetto"

out=$("$O" switch "$A"); echo "  $out" | tail -1
"$O" limit "$A" infinity >/dev/null
systemctl -M "$A" is-active -q aracno-mem || fail "memhog non è più vivo dopo lo switch"
systemctl -M "$A" kill --kill-whom=main -s USR1 aracno-mem
if wait_log '^verify' 240; then grep '^verify' "$LOG" | sed 's/^/  memhog: /'; fi
grep -q "^verify ok" "$LOG" 2>/dev/null || { fail "dati non verificati dopo lo swap"; echo "  log memhog:"; sed "s/^/    /" "$LOG" 2>/dev/null; systemctl -M "$A" status aracno-mem --no-pager 2>&1 | sed "s/^/    /" || true; }
echo "  dopo il rientro: RAM $A $(cur) MB, swap $A $(swp) MB"

echo
if (( fails == 0 )); then
  echo "ESITO 4.5: PASS (aracno limit funziona, anche su tentacolo congelato; dati intatti)"
else
  echo "ESITO 4.5: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
