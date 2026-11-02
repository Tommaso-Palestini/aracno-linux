# ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Un solo filo alla volta deve avere tutta la potenza. Gli altri non devono consumare CPU, ma devono riprendere da dove erano senza riavviarsi.

## Decisione
`aracno switch NOME` congela con `systemctl freeze` tutti i fili attivi tranne `NOME`. Poi scongela `NOME` (`systemctl thaw`), oppure lo avvia se era spento. Il freezer dei cgroup v2 ferma tutti i processi della unit `systemd-nspawn@NOME.service` senza toccarne la memoria.

Misure sul PC di riferimento:
- fase 2: il filo congelato passa a 0% di CPU, quello attivo usa un core pieno, il processo congelato riprende (`prototype/02-test-freeze.sh`);
- fase 3: 40 switch, mediana 69 ms, nessun fallimento; il contatore del filo uscito resta fermo, quello del filo entrato avanza (`prototype/03-bench-switch.sh`, soglia 150 ms);
- fase 4.3: con 512 MB di VRAM allocati, switch in 89 ms (`prototype/06-vram-test.sh`).

## Alternative considerate

### Spegnere e riavviare i fili a ogni switch
- Pro: libera davvero RAM e VRAM.
- Contro: secondi invece di millisecondi, e lo stato dei programmi si perde.
- Scartata come switch normale. Resta lo strumento per liberare risorse (`aracno stop`).

### SIGSTOP/SIGCONT ai processi
- Pro: semplice.
- Contro: bisogna raccogliere tutti i PID con un rischio di race, e i processi possono accorgersene (SIGCONT si può intercettare, il padre riceve SIGCHLD).
- Scartata: il freezer agisce sull'intero cgroup in modo atomico e i processi non lo vedono.

### Solo priorità (CPUWeight/nice) senza congelare
- Pro: i fili in secondo piano continuano a lavorare.
- Contro: consumano comunque CPU e risvegli, quindi l'attivo non ha "tutta la potenza".
- Scartata per l'obiettivo del progetto. Si può riprendere come modalità opzionale.

## Conseguenze
- Congelare libera solo la CPU. **RAM e VRAM di un filo congelato restano occupate** (verificato in fase 4.3: la VRAM si libera solo allo stop del processo). Con 5,7 GB di RAM questo è il limite principale. Misura della fase 4.5 (`prototype/08-ram-limit.sh`): abbassare il tetto (`aracno limit`) su un filo congelato funziona, perché il kernel recupera la memoria senza far girare i processi. 557 MB tolti al filo in ~3,2 s, ma l'host ne guadagna solo ~250, perché lo swap principale è zram e comprime ~1,9:1 restando in RAM. Al rientro i dati sono intatti; rileggere 768 MB dallo swap richiede ~2,4 s.
- Un filo congelato non risponde: niente rete, timer o notifiche finché non torna attivo. Le connessioni aperte possono cadere per timeout.
- Il congelamento è a runtime: un riavvio dell'host spegne tutti i fili.
- Lo switch in bash (~70 ms) basta. Un demone in Rust si valuterà solo se servirà uno stato persistente (vedi le note della roadmap).
- **Watchdog di systemd-nspawn (scoperto il 2026-11-02):** la unit `systemd-nspawn@.service` ha `WatchdogSec=3min`. Il processo `systemd-nspawn` sta nel cgroup del filo e viene congelato con lui, quindi dopo 3 minuti systemd lo considera bloccato e allo scongelamento lo uccide (SIGABRT, `Result=watchdog`). Correzione: drop-in `aracno/data/systemd/systemd-nspawn@.service.d/aracno-watchdog.conf` con `WatchdogSec=0`, verificato da `prototype/15-watchdog-freeze.sh`. Va incluso nell'ISO (fase 5c).
- **Stato di systemd disallineato (scoperto il 2026-11-02):** se un filo muore mentre è congelato, systemd 255 al riavvio dice ancora `FreezerState=frozen` anche se il kernel non lo è (`cgroup.freeze=0`). aracnod legge quindi anche `cgroup.events` (vale il kernel) e prima di switch e stop riallinea systemd. Verifica: `prototype/19-stato-disallineato-test.sh`.
