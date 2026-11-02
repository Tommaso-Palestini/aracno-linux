#!/usr/bin/env bash
# Aracno prototipo — T11: Super+Shift+A apre e chiude il menù a ragnatela su COSMIC.
# Va lanciato SENZA sudo: tocca solo la configurazione dell'utente.
# (Super+A su COSMIC apre la libreria delle applicazioni: scelto Super+Shift+A il 2026-11-02.)
#
#   20-tasto-rapido.sh            aggiunge la scorciatoia
#   20-tasto-rapido.sh --rimuovi  toglie solo la riga di Aracno
#
# Le scorciatoie personalizzate di COSMIC stanno in un file RON:
#   ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom
# con voci del tipo  (modifiers: [Super, Shift], key: "a"): Spawn("aracno-menu"),
# Prima di scrivere: controlla che la combinazione sia libera (scorciatoie di sistema e
# dell'utente) e salva una copia del file. COSMIC rilegge il file da solo.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Lancia SENZA sudo: è la configurazione del tuo utente"; exit 1; }

CARTELLA=$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1
F=$CARTELLA/custom
SISTEMA=/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/defaults
TASTO='(modifiers: [Super, Shift], key: "a")'
RIGA="    $TASTO: Spawn(\"aracno-menu\"),"
NOSTRA='Spawn("aracno-menu")'

copia() { [[ -s $F ]] && cp -p "$F" "$F.prima-di-aracno-$(date +%Y%m%d-%H%M%S)" && echo "  copia salvata: $F.prima-di-aracno-…"; }

if [[ ${1:-} == --rimuovi ]]; then
  [[ -f $F ]] && grep -qF "$NOSTRA" "$F" || { echo "Nessuna scorciatoia di Aracno da togliere."; exit 0; }
  copia
  grep -vF "$NOSTRA" "$F" >"$F.nuovo" && mv "$F.nuovo" "$F"
  echo "Scorciatoia di Aracno tolta."; exit 0
fi

command -v aracno-menu >/dev/null || { echo "aracno-menu non è nel PATH: lancia prima 11-install-aracnod.sh"; exit 1; }

if [[ -f $F ]] && grep -qF "$NOSTRA" "$F"; then
  echo "La scorciatoia di Aracno c'è già:"; grep -F "$NOSTRA" "$F" | sed 's/^/  /'; exit 0
fi
for g in "$SISTEMA" "$F"; do
  if [[ -f $g ]] && grep -qF "$TASTO" "$g"; then
    echo "Super+Shift+A è già usato in $g:"; grep -F "$TASTO" "$g" | sed 's/^/  /'
    echo "Non cambio niente."; exit 1
  fi
done

mkdir -p "$CARTELLA"
if [[ ! -s $F ]] || ! grep -q '}' "$F"; then
  printf '{\n%s\n}\n' "$RIGA" >"$F"
else
  copia
  # la riga va prima dell'ultima graffa chiusa del file
  awk -v riga="$RIGA" '{ l[NR] = $0 } END {
        u = 0; for (i = NR; i >= 1; i--) if (l[i] ~ /}/) { u = i; break }
        for (i = 1; i <= NR; i++) { if (i == u) print riga; print l[i] } }' "$F" >"$F.nuovo"
  mv "$F.nuovo" "$F"
fi
echo "Aggiunta in $F:"
sed 's/^/  /' "$F"
echo
echo "Prova: premi Super+Shift+A (apre il menù), poi di nuovo Super+Shift+A o Esc (lo chiude)."
