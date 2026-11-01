# Mappa dei componenti: menù a tentacoli

Il menù (ADR-0007) contiene due capacità che si possono testare separatamente:
1. un servizio di sistema che esegue lo switch;
2. un'interfaccia che lo chiede.

Le separo perché il componente con i privilegi deve essere piccolo, verificabile e indipendente dalla grafica. È lo schema dei servizi Linux distribuiti (NetworkManager, udisks, fwupd): demone di sistema + D-Bus + polkit, interfacce senza privilegi.

| Id modulo | Responsabilità | Dipende da |
|---|---|---|
| `octopus-proto` | Interfaccia D-Bus condivisa: nomi, metodi, tipi, validazione dei nomi dei tentacoli | — |
| `octod` | Demone di sistema: elenca i tentacoli, fa switch/stop tramite systemd, controlla i permessi con polkit | `octopus-proto` |
| `octo-menu` | Schermata a tutto schermo per l'utente, client di `octod`, nessun privilegio | `octopus-proto` |

Ordine di costruzione: `octopus-proto` → `octod` → `octo-menu`.

Spec: [SPEC-octod.md](SPEC-octod.md) (comprende `octopus-proto`), [SPEC-octo-menu.md](SPEC-octo-menu.md).

La CLI `prototype/octo` resta lo strumento del prototipo. Diventerà un client di `octod` in un passo successivo, fuori da questa mappa.
