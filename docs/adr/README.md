# Decisioni architetturali (ADR)

Ogni file registra una decisione: il contesto, cosa si è scelto, le alternative scartate e le conseguenze.
Gli ADR non si cancellano. Se una decisione cambia, si scrive un ADR nuovo che sostituisce il vecchio e si aggiorna lo stato del vecchio ("Sostituita da ADR-XXXX").

Nome dei file: `NNNN-titolo-breve.md`, numerazione progressiva.

| N. | Decisione | Stato |
|----|-----------|-------|
| [0001](0001-tentacoli-systemd-nspawn.md) | Tentacoli come container systemd-nspawn su un unico kernel | Accettata |
| [0002](0002-switch-con-congelamento-cgroup.md) | Switch con il freezer dei cgroup (`systemctl freeze`) | Accettata |
| [0003](0003-rete-condivisa-con-host.md) | Rete dei tentacoli condivisa con l'host | Accettata |
| [0004](0004-gpu-bind-dev-dri.md) | GPU nei tentacoli: bind di `/dev/dri` con drop-in systemd | Accettata |
| [0005](0005-solo-socket-wayland.md) | Desktop: nei tentacoli si monta solo il socket Wayland | Accettata, da rivedere prima dell'uso quotidiano |
| [0006](0006-host-debian-trixie-live-build.md) | Host dell'ISO: Debian trixie costruita con `live-build` | Accettata |

Nota: le decisioni 0001–0005 sono state prese e verificate durante le fasi 0–4.4 del prototipo, tra ottobre e il 31/10/2026. Sono state messe per scritto il 01/11/2026, quindi le alternative sono una ricostruzione fatta dopo.
