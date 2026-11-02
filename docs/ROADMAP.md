# Aracno Linux — roadmap

Stato aggiornato al 31/10/2026. Legenda: `[x]` fatto e verificato sul PC, `[ ]` da fare.

## Decisioni prese

- **Host:** Debian trixie, costruita con `live-build`. Motivo: stessa base dei fili Debian, più leggera di Pop!_OS. Pop!_OS resta il riferimento per l'hardware.
- **Fili:** container systemd-nspawn sul kernel dell'host. Debian e Arch.
- **Rete dei fili:** condivisa con l'host (`VirtualEthernet=no`).
- **GPU:** `/dev/dri` montato nei fili, con drop-in systemd per i device.
- **Desktop:** solo il socket Wayland dell'utente è montato nei fili (non D-Bus né PulseAudio).

## Fatto

- [x] Fase 0–1: setup e due fili (Debian e Arch)
- [x] Fase 2: switch con congelamento, il filo attivo ha tutta la CPU
- [x] Fase 3: benchmark switch, 40 cicli, mediana 69 ms, zero fallimenti (`prototype/03-bench-switch.sh`)
- [x] Fase 4.1: GPU visibile dentro ogni filo (`prototype/04-gpu-bind.sh`)
- [x] Fase 4.2: driver hardware RADV (AMD Radeon Vega 10) dentro ogni filo (`prototype/05-gpu-driver.sh`)
- [x] Fase 4.3: la VRAM di un filo congelato resta occupata e si libera allo stop; switch 89 ms (`prototype/06-vram-test.sh`)
- [x] Fase 4.4: finestra Wayland dal filo sul desktop COSMIC; il cubo si ferma allo switch e riprende (`prototype/07-wayland-bind.sh`)
- [x] Fase 4.5: `aracno limit` funziona anche su un filo congelato: tetto a 256M in ~3,2 s, 557 MB tolti al filo ma solo ~250 MB guadagnati dall'host (zram ~1,9:1); dati intatti al rientro, rilettura di 768 MB in 2,4 s (`prototype/08-ram-limit.sh`)
- [x] Fase 4.6: `aracno upgrade` aggiorna debian e arch e rimette lo stato (attiva, congelata, spenta); nome inesistente rifiutato (`prototype/09-upgrade-test.sh`)
- [x] Repo su GitHub: `Tommaso-Palestini/aracno-linux`

## Da fare

### Subito
- [x] **ADR:** decisioni registrate in `docs/adr/` (0001–0006: nspawn, freezer, rete condivisa, GPU, socket Wayland, base ISO)
- [x] **Scelta del menù a ragnatela:** schermata a tutto schermo con tasto rapido (ADR-0007)
- [ ] **Menù a ragnatela:** spec approvate (`docs/spec/`), ora piano e implementazione (`spec-driven-development`, `security-and-hardening`, `frontend-ui-engineering`, `design-taste-frontend`)
- [ ] **`aracno upgrade`, copia di sicurezza:** snapshot del filo prima di aggiornare (su ext4 costa una copia intera; valutare btrfs per l'ISO)
- [ ] **RAM dei fili congelati:** decidere la politica (tetto automatico allo switch? quanto basso? zram o swap su disco per i congelati?). Dato di partenza: fase 4.5
- [ ] **Socket Wayland:** rivedere il compromesso prima di un uso quotidiano

### Fase 5 — ISO installabile (base: Debian trixie, `live-build`)
- [ ] **5a:** costruire una prima ISO Debian minimale con `live-build`, che si avvia e basta
- [ ] **5b:** fili creati offline: immagini Debian e Arch dentro l'ISO, niente `debootstrap` o `docker pull` a runtime
- [ ] **5c:** primo boot automatico: fili, socket Wayland, GPU e menù partono da soli
- [ ] **5d:** test su VM o disco di prova, non sul PC di lavoro
- [ ] **5e:** disco cifrato con due password all'avvio (prima LUKS, poi login), come su Pop!_OS (ADR-0009)

### Obiettivo: live su chiavetta
- [ ] **Live USB:** l'ISO avviata da chiavetta, senza installazione, con i fili funzionanti
- [ ] **Installazione su disco** da quella stessa ISO

### Obiettivo finale (da ragionare più avanti)
- [ ] **Selettore di distro su GitHub:** chi scarica il repo sceglie quale distro (o quale filo) installare. Da progettare dopo che l'OS è pronto: va deciso cosa è il prodotto (ISO, script, o entrambi) e come si distribuisce.

## Note
- Rust: valutarlo solo se un componente deve restare in esecuzione (demone, menù con stato). Lo switch è già veloce (~70 ms) con bash.
- Ogni fase si chiude solo con un test reale sul PC, con criterio scritto prima (principio 2 e 3 di `CLAUDE.md`).
