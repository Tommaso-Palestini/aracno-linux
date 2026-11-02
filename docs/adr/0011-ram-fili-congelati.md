# ADR-0011: RAM dei fili congelati: nessun tetto automatico, ci pensa il kernel

## Stato
Accettata (2026-11-02).

## Contesto
Congelare un filo libera la CPU, non la RAM (ADR-0002). Con 5,7 GB sul PC di riferimento la
domanda della roadmap era: serve un tetto di RAM automatico ai fili congelati allo switch? Dato
di partenza (fase 4.5): abbassare a mano il tetto di un filo congelato (`aracno limit`)
funziona, ma con lo swap su zram l'host guadagna circa metà di quanto si toglie.

Applicare un tetto o una protezione a ogni switch richiederebbe ad aracnod il permesso polkit di
cambiare le proprietà delle unit dei fili (`set-property`). polkit non distingue quale proprietà
si cambia: con quel permesso aracnod potrebbe cambiare anche, per esempio, i dispositivi
accessibili a un filo. Prima di allargare i permessi, la domanda era se serve davvero.

## Misura
`prototype/23-ram-pressione-test.sh`, 2026-11-02. Arch congelato con 800 MB occupati; in debian
(attivo) un programma con 500 MB di lavoro **che tocca la sua memoria ogni secondo**; poi in
debian un secondo programma chiede la RAM disponibile + 700 MB.

| Giro | Lavoro del filo attivo | Tolti al congelato | Tolti al lavoro attivo | Rilettura del lavoro |
|---|---|---|---|---|
| 1 | fermo dopo il riempimento | 646 MB | 409 MB | 1172 ms |
| 2 | fermo, `MemoryLow=1G` su debian | 638 MB | 371 MB | 1028 ms |
| 3 | **toccato ogni secondo** | **566 MB** | **0 MB** | **379 ms** |

I giri 1 e 2 misuravano un caso irreale: memoria riempita e mai più usata è fredda quanto quella
del filo congelato, e il kernel non ha motivo di preferirla. Con un lavoro vivo (giro 3) il
kernel toglie memoria solo al filo congelato. Nessun processo ucciso in nessun giro.

Costo dall'altra parte: tornare su arch e rileggere i suoi 800 MB, ormai quasi tutti in zram,
richiede circa 2 s (P3: 1740–2123 ms); lo switch in sé resta sui 45 ms.

## Decisione
- **Nessun tetto o protezione automatica allo switch.** Le pagine di un filo congelato non
  vengono toccate, quindi sono le prime che il kernel libera quando serve memoria; quelle del
  filo in uso restano in RAM.
- aracnod non riceve il permesso `set-property` sulle unit dei fili.
- `aracno limit` (fase 4.5) resta come strumento manuale.

## Alternative considerate
- **Tetto automatico ai fili congelati (MemoryHigh/MemoryMax allo switch)**: libera RAM in
  anticipo anche quando non serve, e il risveglio costa comunque la rilettura da zram. Più
  permessi ad aracnod per un guadagno che il kernel già dà quando serve.
- **`MemoryLow` sul filo attivo a ogni switch**: nel giro 2 non ha cambiato niente, perché la
  pressione nasceva dentro lo stesso filo; e richiede gli stessi permessi.
- **Recupero proattivo (`memory.reclaim`) al congelamento**: aracnod non può scrivere nei cgroup
  (sandbox). Da riconsiderare solo se un caso reale mostrasse lentezze.

## Conseguenze
- Il primo uso di un filo rimasto congelato a lungo sotto pressione può essere lento per qualche
  secondo, il tempo di rileggere dallo swap. Se diventasse fastidioso, un'idea da misurare è
  rileggere in anticipo la memoria del filo subito dopo lo scongelamento.
- La misura vale per il PC di riferimento (kernel 7.1, zram + swap su disco). Su un sistema
  senza swap le pagine anonime del filo congelato non potrebbero essere liberate: l'ISO deve
  avere swap (zram o su disco).
