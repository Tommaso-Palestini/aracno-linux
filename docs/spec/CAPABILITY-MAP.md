# Mappa dei componenti: menù a ragnatela

Il menù (ADR-0007) contiene due capacità che si possono testare separatamente:
1. un servizio di sistema che esegue lo switch;
2. un'interfaccia che lo chiede.

Le separo perché il componente con i privilegi deve essere piccolo, verificabile e indipendente dalla grafica. È lo schema dei servizi Linux distribuiti (NetworkManager, udisks, fwupd): demone di sistema + D-Bus + polkit, interfacce senza privilegi.

| Id modulo | Responsabilità | Dipende da |
|---|---|---|
| `aracno-proto` | Interfaccia D-Bus condivisa: nomi, metodi, tipi, validazione dei nomi dei fili | — |
| `aracnod` | Demone di sistema: elenca i fili, fa switch/stop tramite systemd, controlla i permessi con polkit | `aracno-proto` |
| `aracno-menu` | Schermata a tutto schermo per l'utente, client di `aracnod`, nessun privilegio | `aracno-proto` |

Ordine di costruzione: `aracno-proto` → `aracnod` → `aracno-menu`.

Spec: [SPEC-aracnod.md](SPEC-aracnod.md) (comprende `aracno-proto`), [SPEC-aracno-menu.md](SPEC-aracno-menu.md).

La CLI `prototype/aracno` resta lo strumento del prototipo. Diventerà un client di `aracnod` in un passo successivo, fuori da questa mappa.
