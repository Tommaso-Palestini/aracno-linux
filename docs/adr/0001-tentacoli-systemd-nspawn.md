# ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Octopus deve tenere più distro Linux pronte sullo stesso PC e passare dall'una all'altra in modo rapido, senza riavviare. L'hardware di riferimento è modesto: Ryzen con Radeon Vega e 5,7 GB di RAM. Per questo ogni strato di virtualizzazione costa caro, soprattutto in RAM e GPU.

Requisiti:
- switch in meno di un secondo, che non perda lo stato dei programmi;
- un sistema init vero dentro ogni distro, per avere servizi e sessioni come in una distro installata;
- accesso alla GPU con il driver hardware, non con un renderer software;
- strumenti già presenti in una distro standard, senza un hypervisor da mantenere.

## Decisione
Ogni tentacolo è una cartella in `/var/lib/machines/NOME` avviata con `systemd-nspawn` (`Boot=yes`) e gestita come unit `systemd-nspawn@NOME.service`. Tutti i tentacoli usano il kernel dell'host. La configurazione sta in `/etc/systemd/nspawn/NOME.nspawn`.

- Il tentacolo Debian si crea con `debootstrap` (trixie).
- Il tentacolo Arch si crea esportando l'immagine Docker ufficiale `archlinux:latest` (`prototype/01-create-tentacles.sh`).
- `PrivateUsers=no`: gli UID del container coincidono con quelli dell'host (vedi Conseguenze).

## Alternative considerate

### Macchine virtuali (KVM/QEMU)
- Pro: isolamento forte, ogni distro con il suo kernel.
- Contro: ogni VM riserva RAM; con 5,7 GB ne starebbero una o due. Per la GPU servirebbe il passthrough, che su una iGPU unica non è praticabile, oppure virtio-gpu, più lento.
- Scartata per il costo in RAM e GPU.

### Multiboot (più distro installate, scelta da GRUB)
- Pro: ogni distro a piena potenza, nessun compromesso.
- Contro: lo switch richiede un riavvio, cioè decine di secondi, e lo stato si perde.
- Scartata: va contro l'idea del cambio istantaneo.

### Docker / Podman
- Pro: strumenti diffusi, immagini pronte.
- Contro: pensati per un singolo processo applicativo, non per una distro intera con il suo systemd.
- Scartati come runtime. Docker si usa solo per scaricare il filesystem di Arch.

### LXC/LXD (Incus)
- Pro: container di sistema completi, maturi.
- Contro: è un altro demone da installare. nspawn invece è già in systemd, e lo switch usa il freezer di systemd (ADR-0002).
- Scartato per semplicità. Resta un'opzione se nspawn dovesse mostrare limiti.

## Conseguenze
- Tutti i tentacoli condividono kernel e moduli dell'host, compreso il driver amdgpu. Un tentacolo non può avere un kernel diverso né moduli propri.
- Con `PrivateUsers=no` il root del container ha lo stesso UID del root dell'host. nspawn toglie comunque alcune capability, ma l'isolamento non vale come confine di sicurezza: un tentacolo è di fiducia quanto l'host.
- Creare il tentacolo Arch richiede oggi Docker e la rete. Per l'ISO serve un'altra strada (fase 5b: immagini già dentro l'ISO).
- I tentacoli usano gli strumenti standard: `machinectl`, `systemctl -M`, `systemd-run -M`. La CLI `prototype/octo` ci aggiunge sopra solo uno strato sottile.
