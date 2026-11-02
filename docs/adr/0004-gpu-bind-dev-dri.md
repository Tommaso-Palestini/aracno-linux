# ADR-0004: GPU nei fili con bind di `/dev/dri` e drop-in systemd

## Stato
Accettata

## Data
2026-10-31 (scritta il 2026-11-01)

## Contesto
Il filo attivo deve usare la GPU con il driver hardware (RADV per Vulkan, radeonsi per OpenGL), non con llvmpipe. Siccome il kernel è condiviso (ADR-0001), il driver amdgpu è già caricato. Al container bastano i nodi di `/dev/dri` e le librerie Mesa della propria distro.

Durante la fase 4.1 è emerso che una riga `DeviceAllow=` nel file `.nspawn` non basta. La unit `systemd-nspawn@.service` ha `DevicePolicy=closed`, e il device cgroup blocca l'apertura dei nodi anche quando questi sono visibili.

## Decisione
- Nel `.nspawn` di ogni filo: `[Files] Bind=/dev/dri`.
- Un drop-in `/etc/systemd/system/systemd-nspawn@NOME.service.d/gpu.conf` con `DeviceAllow=/dev/dri/card0 rw` e `DeviceAllow=/dev/dri/renderD128 rw`.
- Dentro ogni filo si installano i driver Mesa Vulkan (`mesa-vulkan-drivers` su Debian, `vulkan-radeon` su Arch).

Verifiche: `/dev/dri/renderD128` è accessibile in ogni filo (`04-gpu-bind.sh`). `vulkaninfo` segnala la GPU AMD e non llvmpipe (`05-gpu-driver.sh`). Le allocazioni Vulkan funzionano e la VRAM si misura dall'host (`06-vram-test.sh`).

## Alternative considerate

### Solo `DeviceAllow=` nel file `.nspawn`
- Scartata: non applicato a causa di `DevicePolicy=closed` della unit (osservato in fase 4.1).

### Rendering software (llvmpipe)
- Pro: nessun accesso ai device.
- Contro: troppo lento per un desktop, contrario a "piena potenza".
- Scartata.

### Passare la GPU a una VM
- Scartata insieme alle VM (ADR-0001): con una iGPU unica non si può dare la GPU a una VM e tenerla anche per l'host.

## Conseguenze
- I nomi `card0` e `renderD128` sono scritti a mano: vanno bene per il PC di riferimento con una sola GPU. Per l'ISO servono regole generiche (ad esempio `DeviceAllow=char-drm rw`) o un rilevamento dei nodi al primo boot (fase 5c).
- La versione di Mesa di ogni filo deve funzionare con il kernel dell'host. Una distro molto vecchia potrebbe non supportarlo bene.
- Accedere a `/dev/dri` permette di usare la GPU, cioè di consumare VRAM e, in teoria, sfruttare bug del driver. È coerente con il livello di fiducia di ADR-0001.
- La VRAM di un filo congelato resta occupata (ADR-0002).
