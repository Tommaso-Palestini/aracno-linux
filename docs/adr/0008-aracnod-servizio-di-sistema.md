# ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus

## Stato
Accettata

## Data
2026-11-01

## Contesto
Lo switch (congelare e scongelare i fili) richiede privilegi. Il menù (ADR-0007) gira come utente e il progetto deve potersi distribuire su più distro. Quindi serve un modo sicuro e standard per far fare a un programma senza privilegi un'operazione privilegiata, **e solo quella**.

Verifiche fatte prima di decidere:
- **Sorgente di systemd v255**: `FreezeUnit` e `ThawUnit` passano a polkit l'azione `org.freedesktop.systemd1.manage-units` con `unit=<nome>` e `verb=stop` per il congelamento, `verb=start` per lo scongelamento. Senza `CAP_SYS_ADMIN` anche root passa da polkit.
- **T1 sul PC** (`prototype/10-polkit-spike.sh`, PASS): su systemd 255 la policy D-Bus di systemd vieta `FreezeUnit` e `ThawUnit` a chi non è root, e la chiamata viene rifiutata prima ancora di arrivare a polkit. Con un file di policy che apre quei due metodi al solo utente `aracno`, la regola polkit decide come previsto: permette start, stop, freeze e thaw sui fili e rifiuta restart, kill, le altre unit, i nomi non validi e gli altri utenti.
- **T2 sul PC**: il menù con layer-shell funziona su COSMIC, e il ripiego a schermo intero funziona dove layer-shell manca.

## Decisione
- **`aracnod`** è un servizio di sistema attivato via D-Bus (`io.github.tommaso_palestini.Aracno1`), scritto in Rust con `zbus`.
- Gira come **utente di sistema dedicato `aracno`**, creato da `sysusers.d`, senza capability.
- I suoi permessi vengono da tre file, tutti in posizioni standard:
  1. `50-aracno.rules` (polkit): `aracno` può solo `start` e `stop` su `systemd-nspawn@<nome valido>.service`. Per lui tutto il resto è NO.
  2. `aracno-systemd-freezer.conf` (policy D-Bus): apre `FreezeUnit` e `ThawUnit` al solo `aracno`. Serve su systemd 255, le versioni più recenti li permettono già.
  3. La policy D-Bus del proprio nome e la sua unit systemd con le restrizioni.
- I client (il menù, in futuro la CLI) chiamano `aracnod`. `aracnod` controlla i chiamanti con le **sue** azioni polkit: `switch` senza password nella sessione attiva, `manage` con la password di amministratore.
- L'elenco dei fili viene da **systemd-machined** (`ListImages`). Stato e RAM vengono letti senza privilegi.

## Alternative considerate

### `aracnod` come root
- Pro: nessuna regola polkit o policy D-Bus da aggiungere per systemd.
- Contro: un bug nel demone avrebbe i privilegi di root. Inoltre senza `CAP_SYS_ADMIN` passerebbe comunque da polkit, quindi la complessità non sparisce.
- Scartata: con un utente dedicato, il danno possibile si riduce a "avviare o fermare i fili".

### Il menù chiama systemd direttamente, con una regola polkit per l'utente
- Pro: nessun demone.
- Contro: qualsiasi programma nella sessione dell'utente potrebbe congelare o fermare i fili. La logica dello switch (congela gli altri, scongela uno, un solo switch alla volta) sarebbe copiata in ogni client. E serve comunque aprire `FreezeUnit` sul bus per l'utente.
- Scartata.

### `sudo` senza password per `aracno` (sudoers)
- Pro: immediato, riusa lo script bash.
- Contro: uno script root che riceve argomenti è esposto all'iniezione di comandi. Non dà autorizzazioni per sessione attiva e non è il modo standard per un'app desktop distribuita.
- Scartata.

### Scrivere direttamente `cgroup.freeze`
- Pro: nessun systemd di mezzo.
- Contro: systemd non saprebbe che la unit è congelata, perché `FreezerState` mente. Inoltre serve comunque scrivere un file di root.
- Scartata.

### Linguaggio: Python o C invece di Rust
- Python: un demone con privilegi che dipende da un interprete e da più librerie. C: rischi di memoria in un componente privilegiato.
- Rust (`zbus` è puro Rust, senza binding C) dà un binario unico e memoria sicura. È il caso previsto dalle note della roadmap: un componente che resta in esecuzione.

## Conseguenze
- L'installazione tocca polkit, D-Bus, sysusers e systemd. Lo script di installazione di sviluppo usa `/etc` e `/usr/local`, i pacchetti useranno `/usr/share` e `/usr/lib`.
- Il file di policy D-Bus per freeze e thaw dipende dalla versione di systemd. Quando le distro di riferimento avranno una versione che li permette già, il file si potrà togliere.
- `aracno limit` (`SetUnitProperties`) usa un verbo diverso e richiederà una decisione esplicita per allargare la regola.
- Tutti i client dipendono da `aracnod`: se non risponde, il menù deve dirlo chiaramente (criterio M4).
