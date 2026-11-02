# ADR-0007: Menù a ragnatela come schermata a tutto schermo

## Stato
Accettata

## Data
2026-11-01

## Contesto
Serve un'interfaccia grafica per lo switch tra fili, che oggi si fa solo con `aracno switch`. Vincoli:
- Il desktop dell'host nell'ISO Debian non è ancora deciso, e COSMIC su trixie non è garantito (ADR-0006).
- Lo switch richiede root (`systemctl freeze`/`thaw`), quindi il menù non può farlo da solo.
- Oggi le finestre di tutti i fili stanno sullo stesso desktop: dopo lo switch quelle dei fili congelati restano visibili ma bloccate (ADR-0005).

## Decisione
Il menù è una **schermata a tutto schermo** sopra il desktop. Si apre con un tasto rapido e mostra i fili disposti a raggiera intorno alla testa, ciascuno con il suo stato (attiva, congelata, spenta). Si sceglie con tastiera o mouse, Invio fa lo switch, Esc chiude.
Più avanti potrà aggiungersi una piccola icona di stato, nella tray o nella barra, per vedere sempre il filo attivo.

## Alternative considerate

### Applet nella barra di COSMIC
- Pro: il filo attivo si vede sempre, integrazione nativa.
- Contro: lega Aracno a COSMIC proprio mentre la base dell'ISO cambia.
- Scartata come menù principale.

### Finestra normale
- Pro: la più semplice, funziona ovunque.
- Contro: scomoda per uno switch frequente, sembra un pannello di controllo.
- Scartata.

### Icona nella tray (StatusNotifier)
- Pro: leggera, mostra lo stato.
- Contro: poco spazio per l'identità visiva, GNOME non la supporta senza estensioni.
- Tenuta come complemento futuro, non come menù.

## Conseguenze
- La schermata deve funzionare con layer-shell di Wayland, che è supportato da COSMIC, KDE e dai compositor wlroots, ma non da GNOME. Il desktop dell'ISO dovrà supportarlo.
- Il tasto rapido si configura in modo diverso su ogni compositor: va gestito al primo boot (fase 5c).
- Serve un componente privilegiato separato che esegua lo switch per conto del menù (regola polkit o piccolo servizio di sistema). Il menù gira come utente e non ha root. Va progettato con la skill `security-and-hardening`.
- La schermata a tutto schermo è il punto naturale dove, più avanti, nascondere o raggruppare le finestre dei fili congelati.
- Tecnologia (GTK4 + gtk4-layer-shell, Rust, altro) da decidere nella spec del menù.
