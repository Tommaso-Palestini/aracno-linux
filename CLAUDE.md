# Octopus Linux — istruzioni per l'agente

Progetto: un sistema con più distro Linux come "tentacoli" (container systemd-nspawn su un unico kernel), un solo tentacolo attivo a piena potenza, menù a tentacoli per lo switch. Prototipo in `prototype/`.

## Principi

1. **Prima la mappa, poi i file.** Se esiste `graphify-out/graph.json`, per domande su architettura, relazioni tra file o "dove sta X" usa `graphify query` / `graphify explain` / `graphify path` invece di rileggere tutto. Apri i file solo per modificarli o per verificare un dettaglio.
   - Dopo modifiche al codice rigenera la mappa con `graphify update .` (nessun LLM richiesto).
2. **Ogni modifica passa dal test reale.** Il prototipo va verificato sul PC (`sudo ./prototype/02-test-freeze.sh`), non solo letto. Una pagina web non prova il cambio di sistema.
3. **Ipotesi prima del codice.** Se una scelta tecnica è rischiosa (GPU, congelamento, storage), scrivi cosa ci aspettiamo e come lo misuriamo, poi implementa.
4. **Piccoli passi verificabili.** Una fase alla volta: setup → due tentacoli → switch con misure → test grafico → installazione da ISO.
5. **Nessun comando privilegiato eseguito da solo.** Gli script con `sudo` li lancia l'utente, con `!` nel prompt.

## Skill del progetto

Le skill in `.claude/skills/` sono copie di quelle di addyosmani/agent-skills. Usale così:
- **spec-driven-development** e **planning-and-task-breakdown**: prima di ogni fase nuova.
- **incremental-implementation** e **test-driven-development**: per ogni modifica.
- **debugging-and-error-recovery**: quando un test fallisce, prima di cambiare codice.
- **security-and-hardening**: per gli script con `sudo` e per i permessi sulle cartelle condivise.
- **frontend-ui-engineering** e **design-taste-frontend**: per il menù a tentacoli e ogni parte grafica.
- **context-engineering**: per gestire il contesto (vedi principio 1).
- **documentation-and-adrs**: per registrare le decisioni tecniche importanti.

## Contesto e comandi utili

- Mappa del codice: `graphify-out/GRAPH_REPORT.md` (sintesi), `graphify-out/graph.html` (visuale).
- Il file `.graphifyignore` esclude `.claude/` e `graphify-out/` dalla mappa.
- Hardware di riferimento: laptop AMD Ryzen con GPU Radeon Vega (Picasso/Raven 2), 5,7 GB RAM, SSD ext4, Pop!_OS 24.04 con COSMIC su Wayland.
