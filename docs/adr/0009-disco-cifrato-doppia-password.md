# ADR-0009: Disco cifrato con LUKS2, due password all'avvio

- Stato: Accettata (2026-11-02), da realizzare nella fase 5
- Riferimenti: ADR-0006 (host Debian trixie con `live-build`), ROADMAP fase 5

## Contesto

L'utente vuole all'accensione lo stesso comportamento di Pop!_OS: prima si sblocca
il disco cifrato (`cryptdata`), poi si entra nel sistema con la password
dell'utente. I fili stanno in `/var/lib/machines`, sulla stessa partizione
dell'host: se il disco non è cifrato, chiunque prenda il PC legge tutti i fili.

## Decisione

1. **Prima password, il disco.** Nell'installazione su disco la partizione di
   sistema è LUKS2 (con LVM dentro: root e swap). Lo sblocco avviene nell'initramfs
   (`cryptsetup-initramfs`), con la richiesta della password grafica di Plymouth.
2. **Seconda password, l'utente.** Dopo il boot si entra dal login grafico con la
   password dell'utente. Le due password sono distinte. L'installer lo dice
   esplicitamente e non propone di usare la stessa.
3. **Cosa resta fuori dalla cifratura:** solo `/boot` e la partizione EFI, come su Pop!_OS.
4. **Live USB:** il sistema live non è cifrato. Se un giorno si aggiunge la
   persistenza sulla chiavetta, quella va cifrata con LUKS.
5. **Swap cifrata**, perché è dentro LUKS: la RAM dei fili congelati che finisce
   in swap non resta in chiaro sul disco.

## Alternative scartate

- **Sblocco automatico con TPM2** (`systemd-cryptenroll`): toglie la prima password,
  che è proprio quello che si vuole. Si può offrire più avanti come opzione.
- **Cifrare solo la home o solo `/var/lib/machines`**: lascia in chiaro
  configurazioni, log e swap.
- **Login automatico dopo lo sblocco del disco**: una password sola. Va contro la richiesta.

## Conseguenze

- Serve un installer che sappia fare LUKS+LVM: `debian-installer` (ricetta
  "crypto") o Calamares, da scegliere in 5a.
- Va misurato quanto costa la cifratura sull'SSD del PC di riferimento (Ryzen con
  AES-NI: ci si aspetta una perdita sotto il 10% in lettura e scrittura sequenziali).
- Il test si fa in VM (fase 5d). Criteri: (a) senza la prima password il sistema non
  parte; (b) con la prima password giusta si arriva al login, che chiede la seconda;
  (c) `lsblk` mostra root e swap dentro `crypt`; (d) i fili partono dopo lo sblocco.
