# Spec: `octo-menu`

Stato: **approvata** il 2026-11-01. Decisione di forma: ADR-0007.

## Obiettivo
Una schermata a tutto schermo che si apre con un tasto rapido, mostra i tentacoli a raggiera intorno alla testa e fa lo switch con un tasto o un clic. Non ha privilegi: chiede tutto a `octod` (SPEC-octod.md).
Successo: aprire il menù, scegliere e tornare al lavoro richiede meno di un secondo e nessuna password, su qualsiasi desktop Wayland con layer-shell. Sugli altri desktop il menù degrada senza rompersi.

User story:
- Come utente, premo il tasto rapido e vedo subito quale tentacolo è attivo, quali sono congelati o spenti e quanta RAM usano.
- Come utente, scelgo un tentacolo con le frecce e Invio, oppure con il mouse, e il menù si chiude a switch fatto.
- Come utente che usa solo la tastiera o un lettore di schermo, posso fare tutto senza mouse, e lo stato non è indicato solo dal colore.

## Assunzioni
1. Il menù gira nella sessione dell'utente, come utente normale.
2. Il tasto rapido lo configura il desktop: il menù fornisce il comando `octo-menu`, e il collegamento lo crea il primo boot (fase 5c) o l'utente.
3. Prima lingua l'italiano, con traduzioni gettext predisposte da subito, perché il progetto si distribuisce.

## Tech stack
- Rust, nello stesso workspace di `octod`, con `octopus-proto` per il proxy D-Bus.
- GTK4 (`gtk4-rs`) + `gtk4-layer-shell`. Livello `overlay`, tastiera `exclusive`, ancorato ai quattro bordi.
- **Ripiego**: se il compositor non supporta layer-shell (GNOME, X11), una normale finestra GTK a schermo intero. Lo stesso disegno, con meno integrazione.
- Disegno della raggiera: widget GTK disposti in un layout personalizzato, non un canvas, così restano focalizzabili e accessibili. Grafica e animazioni secondo `frontend-ui-engineering` e `design-taste-frontend`.
- Versioni esatte da fissare nella fase Plan sulla documentazione aggiornata.

## Comportamento
- `octo-menu` lanciato una seconda volta mentre è aperto lo chiude: il tasto rapido apre e chiude. Un'istanza unica tramite `GApplication`.
- Tastiera: frecce o Tab per muoversi, Invio per lo switch, Esc per chiudere. Il primo elemento selezionato è il tentacolo attivo.
- Ogni tentacolo mostra il nome, lo stato come testo e icona (`attiva`, `congelata`, `spenta`) e la RAM.
- Durante lo switch: un indicatore sul tentacolo scelto. Alla risposta di `octod` il menù si chiude. In caso di errore (`NotAuthorized`, `Busy`, `octod` non raggiungibile) mostra un messaggio chiaro e resta aperto.
- Lo stato si aggiorna dal segnale `StateChanged`, senza interrogazioni continue.
- La voce "+ nuovo tentacolo" del bozzetto **non è nella v1**.

## Comandi
```
Build:  cargo build --release -p octo-menu
Test:   cargo test -p octo-menu
Avvio:  /home/xenon/Desktop/progetti-personal/idea-linux/octopus/target/release/octo-menu
```

## Struttura
```
octopus/octo-menu/
  src/main.rs        avvio, istanza unica, layer-shell o ripiego
  src/radial.rs      layout a raggiera (logica pura, testabile)
  src/client.rs      proxy D-Bus verso octod
  src/view.rs        widget e stato
  data/              .desktop, icone, CSS
  po/                traduzioni
```

## Strategia di test
- **Unitari**: posizioni della raggiera per 1–8 tentacoli, senza sovrapposizioni dentro uno schermo di 1366×768; lo stato di `octod` tradotto nello stato della vista; la gestione di ogni errore.
- **Sul PC**, a mano, con criteri scritti prima:
  - M1: dal tasto rapido alla schermata visibile in < 200 ms, misurato con un timestamp nel log.
  - M2: switch con Invio, menù chiuso, tentacolo giusto attivo (verificato con `octo list`).
  - M3: tutto da tastiera, senza mouse.
  - M4: `octod` fermo o permesso negato, messaggio di errore, nessun crash.
  - M5: su COSMIC con layer-shell; in una sessione senza layer-shell (per esempio GNOME in VM) con la finestra a schermo intero.
- Screenshot per la revisione grafica (`design-taste-frontend`).

## Confini
- **Sempre**: tutte le azioni passano da `octod`; lo stato si mostra anche come testo, non solo come colore; le stringhe vanno in gettext.
- **Chiedere prima**: aggiungere azioni oltre a switch (stop, limit, nuovo tentacolo); cambiare il toolkit.
- **Mai**: chiamare `sudo`, `systemctl` o `octo` direttamente; chiedere privilegi; leggere i file dei tentacoli.

## Criteri di successo
1. M1–M5 passano.
2. Il menù non contiene codice privilegiato: l'unico canale verso il sistema è D-Bus verso `octod`.
3. La revisione grafica è superata (nessun aspetto "da template"), con lo screenshot nel commit.

## Domande aperte
- ~~Tasto rapido?~~ Deciso il 2026-11-01: **`Super+O`** (da verificare che su COSMIC sia libero).
