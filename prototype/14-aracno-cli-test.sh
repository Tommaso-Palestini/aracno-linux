#!/usr/bin/env bash
# Aracno prototipo — T7b: verifica il comando `aracno` (aracno-cli) installato in /usr/local/bin.
# Va lanciato SENZA sudo, dalla sessione grafica. Non chiede password: `aracno snip`
# (Stop, con password) è già coperto dal test 13 sull'API e qui si prova solo il rifiuto del nome.
# Prima: reinstallare con prototype/11-install-aracnod.sh (installa anche `aracno`).
#
# Ipotesi e criteri (scritti prima del test):
#   C1 `aracno web` mostra debian e arch con lo stesso stato di ListStrands (in italiano),
#      il filo attivo per primo; senza terminale non ci sono codici colore
#   C2 `aracno where` stampa solo il nome del filo attivo
#   C3 `aracno hop arch` riesce (codice 0, "sei su arch"), poi `aracno where` dice arch;
#      `aracno hop debian` rimette debian
#   C4 errori chiari e codice 1: `hop Debian` → nome non valido; `hop fedora` → non esiste;
#      `snip Debian` → nome non valido (senza chiedere password); comando sconosciuto → help;
#      `hop` senza filo → uso
#   C5 `aracno watch` riceve gli eventi di uno `hop` lanciato da un altro processo
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
"$A" hop debian >/dev/null

echo; echo ">> C1: web"
out=$("$A" web)
echo "$out" | sed 's/^/    /'
for n in debian arch; do
  atteso=$(it "$(stato_api "$n")")
  grep -qE "[●◌·] $n +$atteso" <<<"$out" && ok "$n: $atteso" || fail "$n: atteso $atteso"
done
[[ $(sed -n 2p <<<"$out") == *"debian"* ]] && ok "il filo attivo è il primo" || fail "debian non è il primo"
grep -q $'\x1b' <<<"$out" && fail "codici colore senza terminale" || ok "niente colori fuori dal terminale"

echo; echo ">> C2: where"
d=$("$A" where)
[[ $d == debian ]] && ok "where → $d" || fail "where → '$d' (atteso debian)"

echo; echo ">> C3: hop"
out=$("$A" hop arch) && [[ $out == *"sei su arch"* ]] && ok "$out" || fail "hop arch: $out"
d=$("$A" where); [[ $d == arch ]] && ok "where → $d" || fail "where dopo il salto → '$d'"
out=$("$A" hop debian) && ok "$out" || fail "hop debian: $out"

echo; echo ">> C4: errori"
errore "hop Debian" "nome non valido" hop Debian
errore "hop fedora" "non esiste" hop fedora
errore "snip Debian" "nome non valido" snip Debian
errore "comando vola" "aracno help" vola
errore "hop senza filo" "uso: aracno hop FILO" hop

echo; echo ">> C5: watch"
log=$(mktemp); trap 'rm -f "$log"' EXIT
"$A" watch >"$log" 2>&1 & pid=$!
sleep 1
"$A" hop arch >/dev/null; "$A" hop debian >/dev/null
sleep 1; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
sed 's/^/    /' "$log" | tail -6
grep -q "arch → attivo" "$log" && grep -q "debian → attivo" "$log" \
  && ok "eventi ricevuti" || fail "eventi di hop non ricevuti da watch"

echo; echo ">> Ripristino: debian attiva"
"$A" web | sed 's/^/    /'

echo
if (( fails == 0 )); then
  echo "ESITO T7b: PASS (comando aracno: web, where, hop, errori, watch)"
else
  echo "ESITO T7b: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
