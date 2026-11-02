# Spec: fase 5, ISO di Aracno Linux

Stato: **approvata** il 2026-11-02 (desktop: KDE Plasma da misurare per primo; installatore: Calamares; nome: Aracno Linux, `aracno-AAAAMMGG-amd64.iso`). Decisioni di riferimento: ADR-0006 (host Debian
trixie con `live-build`), ADR-0009 (disco cifrato, due password), ADR-0010 (socket Wayland
etichettato), ADR-0011 (RAM, serve swap), ADR-0012 (fili con utenti separati).

## Obiettivo
Un'ISO che si avvia da chiavetta o in macchina virtuale, mostra un desktop con il menù a
ragnatela e due fili pronti (Debian e Arch), e si installa su disco con il disco cifrato.
Tutto quello che oggi si ottiene a mano con i test 01–25 del prototipo deve succedere da solo.

User story:
- Come persona che prova Aracno, avvio l'ISO e in meno di due minuti sono sul desktop; premo
  Super+Shift+A e passo da Debian ad Arch, senza rete.
- Come persona che lo installa, scelgo il disco, metto la password del disco e quella
  dell'utente; al riavvio il PC chiede prima l'una e poi l'altra (ADR-0009).
- Come sviluppatore, un solo comando costruisce l'ISO e un altro la prova in una VM.

## Mappa dei moduli

| Modulo | Cosa fa | Dipende da |
|---|---|---|
| `costruzione` | Ambiente Debian trixie per costruire (container nspawn dedicato, **non** un filo), `live-build` di Debian, compilazione di aracnod, aracno, aracno-menu contro le librerie di trixie | — |
| `prova-vm` | Avvio dell'ISO (e del disco installato) in QEMU/KVM con controlli automatici dal log seriale | — |
| `iso-base` | 5a: ISO che si avvia fino al desktop, con aracnod, aracno, aracno-menu e i file di sistema installati | `costruzione` |
| `fili-offline` | 5b: immagini dei fili dentro l'ISO, create al momento della costruzione (Debian con `debootstrap`, Arch dal tarball ufficiale `archlinux-bootstrap`, senza Docker); nessuna rete al primo avvio | `costruzione` |
| `primo-avvio` | 5c: un unico generatore della configurazione oggi sparsa nei test (`.nspawn` con ADR-0012, drop-in watchdog e GPU, regola udev, servizi utente del socket Wayland, scorciatoia Super+Shift+A); si esegue al primo avvio | `iso-base`, `fili-offline` |
| `installatore` | Installazione su disco con LUKS2 + LVM (root e swap), sblocco nell'initramfs, poi login (5e, ADR-0009) | `iso-base`, `primo-avvio` |

Ordine: `costruzione`, `prova-vm` → `iso-base` → `fili-offline` → `primo-avvio` → `installatore`.
`prova-vm` serve a tutti e si costruisce subito insieme a `costruzione`.

## Assunzioni (correggimi ora, altrimenti procedo così)
1. **Si costruisce dentro un container Debian trixie dedicato** (`aracno-costruttore`), con
   privilegi (live-build deve montare e fare chroot). Non è un filo: non compare nel menù,
   non ha GPU né Wayland. Il `live-build` di Ubuntu (3.0~a57) è troppo vecchio per trixie.
2. **Architettura amd64, avvio UEFI e BIOS**, come le ISO live di Debian.
3. **La VM di prova usa QEMU/KVM** (`qemu-system-x86`, `ovmf`), da installare con apt sull'host.
   RAM della VM: 3 GB (il PC ne ha 5,7).
4. **Lo stesso utente e la stessa lingua del prototipo**: un utente creato dall'installatore;
   nel sistema live un utente `aracno` senza password. Lingua di default inglese, italiano
   disponibile (il menù ha già la traduzione).
5. **I binari Rust si compilano nel costruttore** contro le librerie di trixie (niente rpath
   verso `~/.local`: trixie ha `libgtk4-layer-shell` nei pacchetti, da verificare).
6. **L'ISO resta sotto i 4 GB** (sistema + due fili da circa 1,3 GB ciascuno), quindi va su
   una chiavetta da 8 GB.

## Tech stack
- Debian trixie, `live-build` di Debian (versione di trixie), `debootstrap`.
- Arch: tarball ufficiale `archlinux-bootstrap-x86_64.tar.zst` da un mirror, con verifica
  della firma.
- Installatore: **Calamares** (quello delle ISO live di Debian, grafico, sa fare LUKS) —
  vedi domanda aperta 2.
- VM: QEMU/KVM con OVMF (UEFI), console seriale per i controlli automatici.
- Desktop dell'host: **KDE Plasma** (deciso il 2026-11-02), se in VM ha `zwlr_layer_shell_v1` e `wp_security_context_manager_v1`; altrimenti si torna su questa scelta.

## Comandi (obiettivo)
```
Costruttore:  sudo /home/xenon/Desktop/progetti-personal/idea-linux/iso/costruttore.sh   # crea o aggiorna il container
ISO:          sudo /home/xenon/Desktop/progetti-personal/idea-linux/iso/costruisci.sh     # → iso/out/aracno-AAAAMMGG-amd64.iso
Prova live:   /home/xenon/Desktop/progetti-personal/idea-linux/iso/prova-vm.sh iso/out/aracno-….iso
Prova disco:  /home/xenon/Desktop/progetti-personal/idea-linux/iso/prova-vm.sh --disco iso/out/disco.qcow2
```

## Struttura
```
iso/
  costruttore.sh     crea il container Debian trixie per costruire
  costruisci.sh      lancia live-build nel costruttore, mette l'ISO in iso/out/
  prova-vm.sh        QEMU/KVM + controlli dal log seriale
  config/            configurazione live-build (package-lists, hooks, includes.chroot)
  fili/              come si creano le immagini dei fili al momento della costruzione
  primo-avvio/       generatore della configurazione (oggi sparsa nei test 11, 15, 20, 24, 25)
  out/               ISO e dischi di prova (ignorati da git)
```

## Stile
- Script bash con `set -euo pipefail`, commenti in italiano, ipotesi e criteri in testa (come
  `prototype/`). Ogni valore fisso (UID, nomi dei socket) si ricava, non si scrive a mano: è
  il difetto degli script della fase 0–4 (ADR-0010, ADR-0012).
- Nessun file dei fili o della configurazione copiato a mano: tutto nasce da `iso/`.

## Strategia di test
- **Automatici, in VM** (`prova-vm.sh`): l'ISO si avvia; dal log seriale si leggono
  `systemctl is-system-running`, lo stato dei fili (`aracno web`), lo switch (`aracno hop`),
  i protocolli Wayland visti da un filo (lo spike `wayland-globali`, come T14), gli UID
  mappati (come T15). Criteri scritti prima, come nei test del prototipo.
- **A occhio, in VM**: desktop, menù con Super+Shift+A, installazione cifrata, due password.
- **Sul PC vero, alla fine**: la chiavetta avvia il PC (live), senza installare.

## Confini
- **Sempre**: costruire e provare solo in container e VM; il PC di lavoro non viene toccato
  dall'ISO finché non lo decidi tu. Criteri scritti prima di ogni prova.
- **Chiedere prima**: installare pacchetti sull'host (qemu, ovmf); scaricare immagini grandi;
  cambiare il desktop dell'host; qualsiasi prova di installazione su un disco vero.
- **Mai**: scrivere su dischi reali da script; mettere password vere nei file del repo.

## Criteri di successo
1. `costruisci.sh` produce un'ISO riproducibile (stessi comandi, stesso risultato) in meno di
   un'ora sul PC di riferimento.
2. In VM, live: desktop in meno di 2 minuti; due fili presenti senza rete; `aracno hop` e il
   menù funzionano; i fili hanno utenti separati e il socket Wayland etichettato.
3. In VM, installato: chiede la password del disco, poi quella dell'utente; dopo il login vale
   tutto il punto 2; `lsblk` mostra root e swap dentro `crypt`.
4. Sul PC vero, da chiavetta: avvio live fino al desktop e switch tra i fili.

## Domande (risolte il 2026-11-02: 1 Plasma da misurare, 2 Calamares, 3 nome ok)
1. **Quale desktop sull'host dell'ISO?** Aracno ha bisogno di un compositor con `layer-shell`
   (il menù) e `wp_security_context_v1` (ADR-0010). Oggi usi COSMIC, che non è nei pacchetti
   di Debian trixie. Candidati da misurare in VM con lo spike `wayland-globali`:
   - **KDE Plasma** (KWin): desktop completo, layer-shell sì; security-context da verificare.
   - **Sway**: entrambi i protocolli dovrebbero esserci, ma è un gestore a finestre a tasselli,
     poco adatto a chi non lo conosce.
   - **COSMIC da sorgente o da repository esterni**: lo stesso desktop di oggi, ma più lavoro
     e meno stabile su Debian.
   - GNOME: niente layer-shell (il menù andrebbe nel ripiego a schermo intero).
   La mia proposta: misurare Plasma per primo; se ha entrambi i protocolli, è lui.
2. **Installatore**: Calamares (grafico, quello di Debian Live) o `debian-installer` (testuale,
   la ricetta "crypto" fa LUKS+LVM da sola)? Proposta: Calamares, da verificare che faccia
   LUKS2 con swap cifrata.
3. **Nome e marchio**: ISO `aracno-AAAAMMGG-amd64.iso`, nome del sistema "Aracno Linux". Va bene?
