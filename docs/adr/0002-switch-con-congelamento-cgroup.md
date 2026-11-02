# ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Un solo tentacolo alla volta deve avere tutta la potenza. Gli altri non devono consumare CPU, ma devono riprendere da dove erano senza riavviarsi.

## Decisione
`aracno switch NOME` congela con `systemctl freeze` tutti i tentacoli attivi tranne `NOME`. Poi scongela `NOME` (`systemctl thaw`), oppure lo avvia se era spento. Il freezer dei cgroup v2 ferma tutti i processi della unit `systemd-nspawn@NOME.service` senza toccarne la memoria.

Misure sul PC di riferimento:
- fase 2: il tentacolo congelato passa a 0% di CPU, quello attivo usa un core pieno, il processo congelato riprende (`prototype/02-test-freeze.sh`);
- fase 3: 40 switch, mediana 69 ms, nessun fallimento; il contatore del tentacolo uscito resta fermo, quello del tentacolo entrato avanza (`prototype/03-bench-switch.sh`, soglia 150 ms);
- fase 4.3: con 512 MB di VRAM allocati, switch in 89 ms (`prototype/06-vram-test.sh`).

## Alternative considerate

### Spegnere e riavviare i tentacoli a ogni switch
- Pro: libera davvero RAM e VRAM.
- Contro: secondi invece di millisecondi, e lo stato dei programmi si perde.
- Scartata come switch normale. Resta lo strumento per liberare risorse (`aracno stop`).

### SIGSTOP/SIGCONT ai processi
- Pro: semplice.
- Contro: bisogna raccogliere tutti i PID con un rischio di race, e i processi possono accorgersene (SIGCONT si può intercettare, il padre riceve SIGCHLD).
- Scartata: il freezer agisce sull'intero cgroup in modo atomico e i processi non lo vedono.

### Solo priorità (CPUWeight/nice) senza congelare
- Pro: i tentacoli in secondo piano continuano a lavorare.
- Contro: consumano comunque CPU e risvegli, quindi l'attivo non ha "tutta la potenza".
- Scartata per l'obiettivo del progetto. Si può riprendere come modalità opzionale.

## Conseguenze
- Congelare libera solo la CPU. **RAM e VRAM di un tentacolo congelato restano occupate** (verificato in fase 4.3: la VRAM si libera solo allo stop del processo). Con 5,7 GB di RAM questo è il limite principale. Misura della fase 4.5 (`prototype/08-ram-limit.sh`): abbassare il tetto (`aracno limit`) su un tentacolo congelato funziona, perché il kernel recupera la memoria senza far girare i processi. 557 MB tolti al tentacolo in ~3,2 s, ma l'host ne guadagna solo ~250, perché lo swap principale è zram e comprime ~1,9:1 restando in RAM. Al rientro i dati sono intatti; rileggere 768 MB dallo swap richiede ~2,4 s.
- Un tentacolo congelato non risponde: niente rete, timer o notifiche finché non torna attivo. Le connessioni aperte possono cadere per timeout.
- Il congelamento è a runtime: un riavvio dell'host spegne tutti i tentacoli.
- Lo switch in bash (~70 ms) basta. Un demone in Rust si valuterà solo se servirà uno stato persistente (vedi le note della roadmap).
