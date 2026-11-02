# ADR-0003: Rete dei fili condivisa con l'host

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
I fili devono andare online come una distro installata: aggiornamenti, browser, installazione di pacchetti (`apt`, `pacman`). Con la configurazione predefinita di una macchina avviata come unit, nspawn crea un'interfaccia virtuale. Questa interfaccia ha bisogno di `systemd-networkd` o di NAT configurati sull'host, e senza di loro il container resta offline. Pop!_OS usa NetworkManager e non configura niente per le interfacce `ve-*`.

## Decisione
Nel file `.nspawn` di ogni filo si imposta `VirtualEthernet=no` nella sezione `[Network]`. Così il container usa lo stesso namespace di rete dell'host: stesse interfacce, stesso IP, stesso DNS. La riga va ripetuta in ogni script che riscrive il file (`01-create-strands.sh`, `04-gpu-bind.sh`). C'è un commento che lo ricorda.

## Alternative considerate

### `VirtualEthernet=yes` con systemd-networkd e NAT
- Pro: ogni filo con la sua interfaccia e il suo firewall, isolamento di rete.
- Contro: bisogna gestire systemd-networkd accanto a NetworkManager, oppure regole NAT a mano, ed è un'altra cosa che può rompersi.
- Scartata per ora. Va rivista se si vuole isolare la rete di un filo.

### Bridge di rete verso la LAN
- Pro: ogni filo appare come un dispositivo distinto sulla rete.
- Contro: non funziona bene sul Wi-Fi di un laptop, che è il caso di riferimento.
- Scartata.

## Conseguenze
- I fili vanno online senza configurazione aggiuntiva.
- Nessun isolamento di rete: un filo vede tutte le interfacce dell'host e può aprire porte su di esse. Due fili non possono ascoltare sulla stessa porta (ma con il congelamento ne è attivo uno alla volta).
- Insieme a `PrivateUsers=no` (ADR-0001), il confine tra filo e host è debole. Va bene per un sistema personale con distro di fiducia, non per eseguire codice non fidato.
