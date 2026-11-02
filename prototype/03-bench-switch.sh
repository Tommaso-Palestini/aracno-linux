#!/usr/bin/env bash
# Aracno prototipo — fase 3: misura lo switch ripetuto e verifica che i processi
# congelati si fermino davvero e riprendano dopo lo switch.
#
# Ogni tentacolo ha un contatore che incrementa ogni 10 ms e scrive il valore
# in /var/tmp (sul filesystem del tentacolo, leggibile dall'host).
#   - tentacolo USCITO: il contatore deve restare fermo dopo lo switch (congelato)
#   - tentacolo ENTRATO: il contatore deve avanzare (ripreso dal punto in cui era)
#
# Criterio di passaggio: nessun fallimento e mediana < 150 ms.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

O="$(dirname "$0")/aracno"
N=${N:-20}
A=debian
B=arch
M=/var/lib/machines
SOGLIA_MS=150

read_count() { cat "$M/$1/var/tmp/aracno-count" 2>/dev/null || echo 0; }

start_counter() {
  systemctl -M "$1" stop aracno-count 2>/dev/null || true
  systemd-run -M "$1" --unit=aracno-count --quiet /bin/sh -c \
    'n=0; while :; do n=$((n+1)); echo $n > /var/tmp/aracno-count; sleep 0.01; done'
}

other_of() { if [[ $1 == "$A" ]]; then echo "$B"; else echo "$A"; fi; }

echo ">> Preparazione"
for n in $A $B; do
  if ! systemctl is-active -q "systemd-nspawn@$n.service"; then "$O" start "$n"; fi
  start_counter "$n"
done
"$O" switch "$A" >/dev/null
sleep 1
echo "contatori avviati"

TIMES=$(mktemp)
FAILS=0

do_switch() {
  local target=$1 other; other=$(other_of "$target")
  local out ms frozen_ok resumed_ok
  local c_target_before c_other_after c_other_later c_target_later

  c_target_before=$(read_count "$target")
  out=$("$O" switch "$target")
  ms=$(sed -n 's/.* in \([0-9]*\) ms/\1/p' <<<"$out")
  c_other_after=$(read_count "$other")

  sleep 1

  c_other_later=$(read_count "$other")
  c_target_later=$(read_count "$target")

  frozen_ok=no; resumed_ok=no
  [[ $c_other_after == "$c_other_later" ]] && frozen_ok=sì
  (( c_target_later > c_target_before )) && resumed_ok=sì

  if [[ $frozen_ok != sì || $resumed_ok != sì || -z $ms ]]; then
    FAILS=$((FAILS + 1))
  fi
  echo "$ms" >> "$TIMES"
  printf "  → %-7s %5s ms | %s congelato: %-3s | %s ripreso: %s\n" \
    "$target" "${ms:-?}" "$other" "$frozen_ok" "$target" "$resumed_ok"
}

echo; echo ">> $N cicli ($A ⇄ $B)"
for i in $(seq "$N"); do
  do_switch "$B"
  do_switch "$A"
done

echo; echo ">> Statistiche sui $(wc -l < "$TIMES") switch"
sort -n "$TIMES" | awk '
  { v[NR] = $1; sum += $1 }
  END {
    med = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
    printf "  min %d ms | mediana %.1f ms | media %.1f ms | max %d ms\n", v[1], med, sum / NR, v[NR]
  }'
echo "  fallimenti (congelamento o ripresa): $FAILS"

MEDIANA=$(sort -n "$TIMES" | awk '{v[NR]=$1} END{print (NR%2)?v[(NR+1)/2]:(v[NR/2]+v[NR/2+1])/2}')
rm -f "$TIMES"

echo; echo ">> Pulizia contatori (i tentacoli restano accesi)"
for n in $A $B; do systemctl -M "$n" stop aracno-count 2>/dev/null || true; done

echo
if (( FAILS == 0 )) && awk -v m="$MEDIANA" -v s="$SOGLIA_MS" 'BEGIN{exit !(m < s)}'; then
  echo "ESITO: PASS (mediana ${MEDIANA} ms < ${SOGLIA_MS} ms, nessun fallimento)"
else
  echo "ESITO: FAIL (fallimenti: $FAILS, mediana: ${MEDIANA} ms, soglia: ${SOGLIA_MS} ms)"
  exit 1
fi
