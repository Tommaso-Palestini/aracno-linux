# ADR-0005: Desktop: nei fili si monta solo il socket Wayland

## Stato
Accettata per il prototipo. Da rivedere prima dell'uso quotidiano (vedi la roadmap).

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Le finestre di un filo devono comparire sul desktop dell'host (COSMIC su Wayland nel prototipo). Un'app grafica Wayland ha bisogno solo del socket del compositor. Audio, notifiche, portali e keyring passano invece da altri canali (PulseAudio/PipeWire, D-Bus di sessione), e ognuno di questi dà al container più accesso alla sessione dell'utente.

## Decisione
`prototype/07-wayland-bind.sh` aggiunge al `.nspawn` di ogni filo una sola riga:
`Bind=/run/user/UID/wayland-1:/run/aracno-wayland/wayland-1`.
Nel container l'app si avvia con `XDG_RUNTIME_DIR=/run/aracno-wayland` e `WAYLAND_DISPLAY=wayland-1`. D-Bus di sessione e PulseAudio/PipeWire non vengono montati.

Verifica (fase 4.4): `vkcube` di ogni filo compare sul desktop COSMIC, si ferma allo switch e riparte.

## Alternative considerate

### Montare l'intera `/run/user/UID`
- Pro: funziona tutto subito, anche audio e D-Bus.
- Contro: il container avrebbe accesso al D-Bus di sessione, al keyring, al portale e a ogni altro socket dell'utente.
- Scartata.

### XWayland / socket X11
- Contro: con X11 ogni client può leggere la tastiera e lo schermo degli altri client.
- Scartata. Le app solo X11 restano da gestire.

### Un compositor annidato per filo (finestra unica)
- Pro: isolamento migliore, ogni filo è "una finestra".
- Contro: più strati, più GPU, meno integrazione con il desktop.
- Non scartata del tutto: c'entra con la scelta del menù a ragnatela.

## Conseguenze
- Ogni filo può aprire finestre sul desktop dell'host. In base ai protocolli che espone il compositor, potrebbe usare anche appunti e cattura dello schermo. Su COSMIC non l'abbiamo verificato: è il compromesso principale da rivedere.
- Mancano audio, notifiche, portali (selettore file) e app X11. Ognuno va aggiunto con una decisione esplicita, montando solo il socket necessario.
- Il percorso del socket dipende dalla sessione: utente `xenon` e `wayland-1` sono valori predefiniti fissi nello script. Se la sessione grafica riparte con un altro nome, il bind non vale più. Per l'ISO va generato al login (fase 5c).
- Il bind si fa all'avvio del container: se il compositor riparte, bisogna riavviare i fili.
