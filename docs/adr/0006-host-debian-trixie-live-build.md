# ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Il prototipo gira su Pop!_OS 24.04. Per arrivare a un prodotto distribuibile (ISO, live su chiavetta, poi installazione) serve un sistema host costruito apposta. Deve essere leggero perché ospita i tentacoli, deve avere systemd recente con nspawn e freezer, e deve potersi costruire in modo ripetibile.

## Decisione
L'host di Octopus è una Debian trixie costruita con `live-build`. Pop!_OS resta il riferimento per l'hardware e la piattaforma su cui si sviluppa il prototipo.

## Alternative considerate

### Rimontare Pop!_OS
- Pro: è la piattaforma già testata, con COSMIC.
- Contro: più pesante, con una sua catena di build difficile da riprodurre fuori da System76.
- Scartata come base dell'ISO.

### Distro da zero (Linux From Scratch, buildroot)
- Pro: controllo totale, minima.
- Contro: troppo lavoro di manutenzione per il progetto.
- Scartata.

### Altre basi (Arch con archiso, Fedora con kiwi)
- Non approfondite. Debian ha vinto perché ha la stessa base del tentacolo Debian, `debootstrap` già in uso e `live-build` maturo.

## Conseguenze
- Il desktop dell'host va scelto e testato su Debian. COSMIC non è garantito su trixie, e la fase 4.4 è stata verificata solo su COSMIC.
- Le immagini dei tentacoli devono stare già dentro l'ISO (fase 5b), senza `debootstrap` o `docker pull` al primo avvio.
- Gli script del prototipo che dipendono dal PC di riferimento (nomi dei device GPU, utente, socket Wayland) vanno resi generici prima della fase 5c.
