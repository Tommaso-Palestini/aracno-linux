#!/usr/bin/env bash
# Aracno — T18 e T19: avvia l'ISO di prova in VM e controlla il rapporto sulla seriale.
# Senza sudo. Uso: iso/verifica-desktop.sh [ISO]   (default: la più recente *-prova.iso)
#
# Criteri (scritti prima):
#   T18 D1 la sessione grafica è Plasma su Wayland
#       D2 il rapporto arriva entro 120 s dall'avvio del kernel (desktop pronto)
#       D3 systemctl is-system-running = running o degraded (si elencano le unit fallite)
#   T19 P1 KWin offre zwlr_layer_shell_v1 (menù) e wp_security_context_manager_v1 (ADR-0010)
#       P2 dal socket etichettato spariscono i protocolli privilegiati noti (appunti, cattura,
#          tastiera virtuale, finestre di sistema, gestione di finestre e monitor di KDE)
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
iso=${1:-$(ls -t "$R"/iso/out/*-prova.iso 2>/dev/null | head -1)}
[[ -f $iso ]] || { echo "Nessuna ISO di prova: sudo iso/costruisci.sh --prova"; exit 1; }
LOG=$R/iso/out/seriale.log
FOTO=$R/iso/out/desktop.png
# protocolli che non devono arrivare a un client in sandbox (nomi esatti; quelli assenti
# anche dal socket normale vengono solo ignorati)
PRIVILEGIATI='^(ext_data_control_manager_v1|zwlr_data_control_manager_v1|zwp_virtual_keyboard_manager_v1|zwp_input_method_manager_v2|org_kde_kwin_fake_input|zwlr_layer_shell_v1|ext_session_lock_manager_v1|ext_image_copy_capture_manager_v1|ext_output_image_capture_source_manager_v1|ext_foreign_toplevel_image_capture_source_manager_v1|zkde_screencast_unstable_v1|org_kde_plasma_window_management|org_kde_plasma_shell|kde_output_management_v2|kde_output_device_v2|zwlr_output_manager_v1|ext_foreign_toplevel_list_v1|zwlr_foreign_toplevel_manager_v1|ext_workspace_manager_v1|wp_security_context_manager_v1)$'

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
campo() { tr -d '\r' <"$LOG" | sed -n "s/^ARACNO-$1 //p"; }

"$R/iso/prova-vm.sh" --senza-finestra --tempo 480 --aspetta '^ARACNO-FINE' --foto "$FOTO" "$iso" || true

echo; echo ">> T18: desktop"
sess=$(campo SESSIONE)
echo "$sess" | sed 's/^/    /'
grep -q 'XDG_SESSION_TYPE=wayland' <<<"$sess" && grep -qi 'XDG_CURRENT_DESKTOP=KDE' <<<"$sess" \
  && ok "D1 Plasma su Wayland" || fail "D1 sessione: $(tr '\n' ' ' <<<"$sess")"
t=$(campo TEMPO | cut -d' ' -f1 | cut -d. -f1)
[[ -n $t ]] && (( t <= 120 )) && ok "D2 desktop pronto a ${t} s" || fail "D2 desktop a '${t:-?}' s (soglia 120)"
s=$(campo SISTEMA)
[[ $s == running || $s == degraded ]] && ok "D3 sistema: $s" || fail "D3 sistema: '${s:-?}'"
campo FALLITO | sed 's/^/    unit fallita: /'
echo "    schermo: $FOTO"

echo; echo ">> T19: protocolli di KWin"
norm=$(campo GLOBALE | cut -d' ' -f1 | sort -u)
sic=$(campo SICURO | cut -d' ' -f1 | sort -u)
echo "    socket normale: $(wc -l <<<"$norm") protocolli; socket etichettato: $(grep -c . <<<"$sic" || true)"
for p in zwlr_layer_shell_v1 wp_security_context_manager_v1; do
  grep -qx "$p" <<<"$norm" && ok "P1 $p" || fail "P1 manca $p"
done
if [[ -n $sic ]]; then
  rimasti=$(grep -E "$PRIVILEGIATI" <<<"$sic" | tr '\n' ' ' || true)
  [[ -z $rimasti ]] && ok "P2 nessun protocollo privilegiato dal socket etichettato" || fail "P2 ancora visibili: $rimasti"
  echo "    nascosti dal socket etichettato: $(comm -23 <(echo "$norm") <(echo "$sic") | tr '\n' ' ')"
else
  fail "P2 nessun elenco dal socket etichettato: $(campo SICURO-LOG | head -3 | tr '\n' ' ')"
fi

echo
if (( fails == 0 )); then echo "ESITO T18+T19: PASS (Plasma su Wayland, layer-shell e socket etichettato ok)"
else echo "ESITO T18+T19: FAIL ($fails controlli). Seriale completa: $LOG"; exit 1; fi
