# Decisioni architetturali (ADR)

Ogni file registra una decisione: il contesto, cosa si è scelto, le alternative scartate e le conseguenze.
Gli ADR non si cancellano. Se una decisione cambia, si scrive un ADR nuovo che sostituisce il vecchio e si aggiorna lo stato del vecchio ("Sostituita da ADR-XXXX").

Nome dei file: `NNNN-titolo-breve.md`, numerazione progressiva.

| N. | Decisione | Stato |
|----|-----------|-------|
| [0001](0001-fili-systemd-nspawn.md) | Fili come container systemd-nspawn su un unico kernel | Accettata |
| [0002](0002-switch-con-congelamento-cgroup.md) | Switch con il freezer dei cgroup (`systemctl freeze`) | Accettata |
| [0003](0003-rete-condivisa-con-host.md) | Rete dei fili condivisa con l'host | Accettata |
| [0004](0004-gpu-bind-dev-dri.md) | GPU nei fili: bind di `/dev/dri` con drop-in systemd | Accettata |
| [0005](0005-solo-socket-wayland.md) | Desktop: nei fili si monta solo il socket Wayland | Accettata, aggiornata da ADR-0010 |
| [0006](0006-host-debian-trixie-live-build.md) | Host dell'ISO: Debian trixie costruita con `live-build` | Accettata |
| [0007](0007-menu-a-tutto-schermo.md) | Menù a ragnatela come schermata a tutto schermo | Accettata |
| [0008](0008-aracnod-servizio-di-sistema.md) | Lo switch passa da `aracnod`: servizio di sistema, utente dedicato, polkit, D-Bus, Rust | Accettata |
| [0009](0009-disco-cifrato-doppia-password.md) | Disco cifrato con LUKS2: password del disco all'avvio, poi password dell'utente | Accettata, da fare nella fase 5 |
| [0010](0010-socket-wayland-etichettato.md) | Nei fili un socket Wayland etichettato (`wp_security_context_v1`): niente appunti letti di nascosto, cattura schermo, tastiera virtuale, layer-shell | Accettata |

Nota: le decisioni 0001–0005 sono state prese e verificate durante le fasi 0–4.4 del prototipo, tra ottobre e il 31/10/2026. Sono state messe per scritto il 01/11/2026, quindi le alternative sono una ricostruzione fatta dopo.
