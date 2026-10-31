# Octopus Linux — roadmap

Stato aggiornato al 31/10/2026. Legenda: `[x]` fatto e verificato sul PC, `[ ]` da fare.

## Decisioni prese

- **Host:** Debian trixie, costruita con `live-build`. Motivo: stessa base dei tentacoli Debian, più leggera di Pop!_OS. Pop!_OS resta il riferimento per l'hardware.
- **Tentacoli:** container systemd-nspawn sul kernel dell'host. Debian e Arch.
- **Rete dei tentacoli:** condivisa con l'host (`VirtualEthernet=no`).
- **GPU:** `/dev/dri` montato nei tentacoli, con drop-in systemd per i device.
- **Desktop:** solo il socket Wayland dell'utente è montato nei tentacoli (non D-Bus né PulseAudio).

## Fatto

- [x] Fase 0–1: setup e due tentacoli (Debian e Arch)
- [x] Fase 2: switch con congelamento, il tentacolo attivo ha tutta la CPU
- [x] Fase 3: benchmark switch, 40 cicli, mediana 69 ms, zero fallimenti (`prototype/03-bench-switch.sh`)
- [x] Fase 4.1: GPU visibile dentro ogni tentacolo (`prototype/04-gpu-bind.sh`)
- [x] Fase 4.2: driver hardware RADV (AMD Radeon Vega 10) dentro ogni tentacolo (`prototype/05-gpu-driver.sh`)
- [x] Fase 4.3: la VRAM di un tentacolo congelato resta occupata e si libera allo stop; switch 89 ms (`prototype/06-vram-test.sh`)
- [x] Fase 4.4: finestra Wayland dal tentacolo sul desktop COSMIC; il cubo si ferma allo switch e riprende (`prototype/07-wayland-bind.sh`)
- [x] Repo su GitHub: `Tommaso-Palestini/octopus-linux`

## Da fare

### Subito
- [ ] **ADR:** registrare in `docs/adr/` le decisioni sopra, con il perché (nspawn, rete condivisa, drop-in GPU, socket Wayland, compromesso di sicurezza)
- [ ] **Scelta del menù a tentacoli:** finestra, applet nella barra, o schermata a tutto schermo (decisione aperta)
- [ ] **Menù a tentacoli:** implementazione dopo la scelta (`frontend-ui-engineering`, `design-taste-frontend`)
- [ ] **Limite RAM:** testare `octo limit` (non ancora verificato)
- [ ] **Socket Wayland:** rivedere il compromesso prima di un uso quotidiano

### Fase 5 — ISO installabile (base: Debian trixie, `live-build`)
- [ ] **5a:** costruire una prima ISO Debian minimale con `live-build`, che si avvia e basta
- [ ] **5b:** tentacoli creati offline: immagini Debian e Arch dentro l'ISO, niente `debootstrap` o `docker pull` a runtime
- [ ] **5c:** primo boot automatico: tentacoli, socket Wayland, GPU e menù partono da soli
- [ ] **5d:** test su VM o disco di prova, non sul PC di lavoro

### Obiettivo: live su chiavetta
- [ ] **Live USB:** l'ISO avviata da chiavetta, senza installazione, con i tentacoli funzionanti
- [ ] **Installazione su disco** da quella stessa ISO

### Obiettivo finale (da ragionare più avanti)
- [ ] **Selettore di distro su GitHub:** chi scarica il repo sceglie quale distro (o quale tentacolo) installare. Da progettare dopo che l'OS è pronto: va deciso cosa è il prodotto (ISO, script, o entrambi) e come si distribuisce.

## Note
- Rust: valutarlo solo se un componente deve restare in esecuzione (demone, menù con stato). Lo switch è già veloce (~70 ms) con bash.
- Ogni fase si chiude solo con un test reale sul PC, con criterio scritto prima (principio 2 e 3 di `CLAUDE.md`).
