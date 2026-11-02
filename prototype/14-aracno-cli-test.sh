#!/usr/bin/env bash
# Aracno prototipo — T7b: verifica il comando `aracno` (aracno-cli) installato in /usr/local/bin.
# Va lanciato SENZA sudo, dalla sessione grafica. Non chiede password: `aracno taglia`
# (Stop, con password) è già coperto dal test 13 sull'API e qui si prova solo il rifiuto del nome.
# Prima: reinstallare con prototype/11-install-aracnod.sh (installa anche `aracno`).
#
# Ipotesi e criteri (scritti prima del test):
#   C1 `aracno ragnatela` mostra debian e arch con lo stesso stato di ListStrands (in italiano),
#      il filo attivo per primo; senza terminale non ci sono codici colore
#   C2 `aracno dove` stampa solo il nome del filo attivo
#   C3 `aracno salta arch` riesce (codice 0, "sei su arch"), poi `aracno dove` dice arch;
#      `aracno salta debian` rimette debian
#   C4 errori chiari e codice 1: `salta Debian` → nome non valido; `salta fedora` → non esiste;
#      `taglia Debian` → nome non valido (senza chiedere password); comando sconosciuto → aiuto;
#      `salta` senza filo → uso
#   C5 `aracno ascolta` riceve gli eventi di uno `salta` lanciato da un altro processo
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
A=/usr/local/bin/aracno
NAME=io.github.tommaso_palestini.Aracno1
OPATH=/io/github/tommaso_palestini/Aracno1

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
it()   { case $1 in active) echo attivo ;; frozen) echo congelato ;; off) echo spento ;; *) echo "?" ;; esac; }
stato_api() { busctl call --system --json=short "$NAME" "$OPATH" "$NAME.Manager" ListStrands \
              | python3 -c 'import sys,json; [print(r[1]) for r in json.load(sys.stdin)["data"][0] if r[0]==sys.argv[1]]' "$1"; }
# errore NOME_TEST TESTO_ATTESO comando...
errore() {
  local d=$1 atteso=$2 out rc=0; shift 2
  out=$("$A" "$@" 2>&1) || rc=$?
  if (( rc == 1 )) && grep -qF "$atteso" <<<"$out"; then ok "$d → $out"
  else fail "$d: codice $rc, uscita: $out (atteso: $atteso)"; fi
}

echo ">> Controllo: aracno installato è quello compilato"
cmp -s "$A" "$R/aracno/target/release/aracno" || { echo "  $A diverso dal compilato: rilancia 11-install-aracnod.sh"; exit 1; }
"$A" salta debian >/dev/null

echo; echo ">> C1: ragnatela"
out=$("$A" ragnatela)
echo "$out" | sed 's/^/    /'
for n in debian arch; do
  atteso=$(it "$(stato_api "$n")")
  grep -qE "[●◌·] $n +$atteso" <<<"$out" && ok "$n: $atteso" || fail "$n: atteso $atteso"
done
[[ $(sed -n 2p <<<"$out") == *"debian"* ]] && ok "il filo attivo è il primo" || fail "debian non è il primo"
grep -q $'\x1b' <<<"$out" && fail "codici colore senza terminale" || ok "niente colori fuori dal terminale"

echo; echo ">> C2: dove"
d=$("$A" dove)
[[ $d == debian ]] && ok "dove → $d" || fail "dove → '$d' (atteso debian)"

echo; echo ">> C3: salta"
out=$("$A" salta arch) && [[ $out == *"sei su arch"* ]] && ok "$out" || fail "salta arch: $out"
d=$("$A" dove); [[ $d == arch ]] && ok "dove → $d" || fail "dove dopo il salto → '$d'"
out=$("$A" salta debian) && ok "$out" || fail "salta debian: $out"

echo; echo ">> C4: errori"
errore "salta Debian" "nome non valido" salta Debian
errore "salta fedora" "non esiste" salta fedora
errore "taglia Debian" "nome non valido" taglia Debian
errore "comando vola" "aracno aiuto" vola
errore "salta senza filo" "uso: aracno salta FILO" salta

echo; echo ">> C5: ascolta"
log=$(mktemp); trap 'rm -f "$log"' EXIT
"$A" ascolta >"$log" 2>&1 & pid=$!
sleep 1
"$A" salta arch >/dev/null; "$A" salta debian >/dev/null
sleep 1; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
sed 's/^/    /' "$log" | tail -6
grep -q "arch → attivo" "$log" && grep -q "debian → attivo" "$log" \
  && ok "eventi ricevuti" || fail "eventi di salta non ricevuti da ascolta"

echo; echo ">> Ripristino: debian attiva"
"$A" ragnatela | sed 's/^/    /'

echo
if (( fails == 0 )); then
  echo "ESITO T7b: PASS (comando aracno: ragnatela, dove, salta, errori, ascolta)"
else
  echo "ESITO T7b: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
