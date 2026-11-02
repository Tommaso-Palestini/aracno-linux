#!/usr/bin/env bash
# Aracno prototipo — T7: verifica Stop di aracnod e restrizioni della unit.
# Va lanciato SENZA sudo, dalla sessione grafica. Al primo Stop COSMIC mostra la finestra
# di polkit con la richiesta della password: inseriscila (è parte del test).
# Usa sudo solo per la prova con "nobody" (O7d).
# Prima: reinstallare aracnod con prototype/11-install-aracnod.sh e rilanciare 12-aracnod-test.sh
# (le restrizioni nuove della unit non devono rompere ListTentacles e Switch).
#
# Ipotesi e criteri (scritti prima del test):
#   O6  systemd-analyze security aracnod.service ≤ 2.0
#   O7a Stop di arch congelata dalla sessione: polkit chiede la password, poi arch è spenta
#   O7b Stop di arch già spenta: riesce senza fare nulla (0 passi), senza chiedere di nuovo la password
#   O7c "Debian" → InvalidName; "fedora" → NotFound
#   O7d Stop chiamato come nobody da un servizio (fuori sessione): NotAuthorized, debian ancora attiva
#   O7e il journal registra lo stop con l'uid del chiamante
#   O7f (aggiunto dopo il primo giro) Switch verso arch spenta subito dopo lo Stop riesce:
#       è il secondo job sulla stessa connessione e systemd risponde AlreadySubscribed a Subscribe
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo, dalla sessione grafica"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
NAME=io.github.tommaso_palestini.Aracno1
OPATH=/io/github/tommaso_palestini/Aracno1

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }

# timeout lungo: il tempo per scrivere la password nella finestra di polkit
call()   { gdbus call --system --timeout 120 --dest "$NAME" --object-path "$OPATH" --method "$NAME.Manager.$1" "${@:2}"; }
stati()  { busctl call --system --json=short "$NAME" "$OPATH" "$NAME.Manager" ListTentacles \
           | python3 -c 'import sys,json; print(" ".join(f"{r[0]}={r[1]}" for r in json.load(sys.stdin)["data"][0]))'; }
stato_di() { stati | tr ' ' '\n' | sed -n "s/^$1=//p"; }
attesa_errore() {  # attesa_errore NOME_ERRORE DESCRIZIONE METODO ARGOMENTI...
  local err=$1 d=$2 out; shift 2
  if out=$(call "$@" 2>&1); then fail "$d: riuscito (atteso $err)"
  elif grep -q "Error\.$err" <<<"$out"; then ok "$d → $err"
  else fail "$d: errore diverso da $err: $out"; fi
}

echo ">> Controllo: aracnod installato è quello compilato"
inst=$(sha256sum /usr/local/libexec/aracnod 2>/dev/null | cut -c1-64 || true)
comp=$(sha256sum "$R/aracno/target/release/aracnod" | cut -c1-64)
[[ $inst == "$comp" ]] || { echo "  non aggiornato: lancia prima sudo $R/prototype/11-install-aracnod.sh"; exit 1; }
cmp -s "$R/aracno/data/systemd/aracnod.service" /etc/systemd/system/aracnod.service \
  || { echo "  unit installata non aggiornata: lancia prima sudo $R/prototype/11-install-aracnod.sh"; exit 1; }
T0=$(date '+%Y-%m-%d %H:%M:%S')

echo; echo ">> O6: esposizione della unit"
punteggio=$(systemd-analyze security aracnod.service 2>/dev/null | sed -n 's/.*Overall exposure level for aracnod.service: \([0-9.]*\).*/\1/p')
echo "  punteggio: ${punteggio:-?}"
python3 -c "import sys; sys.exit(0 if float('${punteggio:-99}') <= 2.0 else 1)" \
  && ok "esposizione ${punteggio} ≤ 2.0" || fail "esposizione ${punteggio:-?} > 2.0"

echo; echo ">> Preparazione: debian attiva, arch congelata"
call Switch arch >/dev/null; call Switch debian >/dev/null
echo "  $(stati)"

echo; echo ">> O7a: Stop di arch congelata — SCRIVI LA PASSWORD nella finestra di polkit"
if out=$(call Stop arch 2>&1); then ok "Stop arch: $out"; else fail "Stop arch: $out"; fi
[[ $(stato_di arch) == off ]] && ok "arch spenta ($(stati))" || fail "arch: $(stato_di arch)"

echo; echo ">> O7b: Stop di arch già spenta (non deve chiedere di nuovo la password)"
if out=$(call Stop arch 2>&1); then ok "Stop arch di nuovo: $out"; else fail "secondo Stop: $out"; fi
log0=$(journalctl -u aracnod.service --since "$T0" --no-pager -o cat | grep "stop arch (uid $(id -u)): ok in .* 0 passi" | tail -1 || true)
[[ -n $log0 ]] && ok "nessun passo eseguito ($log0)" || fail "il secondo Stop non risulta a 0 passi"

echo; echo ">> O7c: nomi"
attesa_errore InvalidName '"Debian"' Stop Debian
attesa_errore NotFound '"fedora"' Stop fedora

echo; echo ">> O7d: Stop come nobody da un servizio (chiede la password di sudo)"
if out=$(sudo systemd-run --quiet --wait --pipe --collect --uid=nobody --gid=nogroup \
           gdbus call --system --dest "$NAME" --object-path "$OPATH" \
           --method "$NAME.Manager.Stop" debian 2>&1); then fail "nobody: Stop riuscito"
elif grep -q "Error\.NotAuthorized" <<<"$out"; then ok "nobody → NotAuthorized"
else fail "nobody: errore inatteso: $out"; fi
[[ $(stato_di debian) == active ]] && ok "debian ancora attiva" || fail "debian: $(stato_di debian)"

echo; echo ">> O7e: journal"
log=$(journalctl -u aracnod.service --since "$T0" --no-pager -o cat | grep "stop arch (uid $(id -u)): ok" | head -1 || true)
[[ -n $log ]] && ok "journal: $log" || fail "nel journal manca lo stop con uid $(id -u)"

echo; echo ">> O7f: Switch verso arch spenta dopo lo Stop (secondo job sulla stessa connessione di aracnod)"
if out=$(call Switch arch 2>&1); then ok "Switch arch: $out"; else fail "Switch arch dopo Stop: $out"; fi
[[ $(stato_di arch) == active ]] && ok "arch attiva ($(stati))" || fail "arch: $(stato_di arch)"

echo; echo ">> Ripristino: debian attiva, arch congelata"
call Switch debian >/dev/null || true
echo "  $(stati)"

echo
if (( fails == 0 )); then
  echo "ESITO T7: PASS (Stop con password, rifiuti corretti, unit con esposizione ${punteggio})"
else
  echo "ESITO T7: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
