# Piano: menù a tentacoli (`aracnod` + `aracno-menu`)

Spec: `docs/spec/CAPABILITY-MAP.md`, `SPEC-aracnod.md`, `SPEC-aracno-menu.md` (approvate il 2026-11-01).
Task: `tasks/todo.md`.

## Sintesi
Si costruisce un servizio di sistema senza privilegi (`aracnod`, utente `aracno`) che fa switch e stop dei tentacoli parlando con systemd su D-Bus, con i permessi controllati da polkit. Sopra va una schermata a tutto schermo (`aracno-menu`) che gira come utente e chiede tutto a `aracnod`. Prima si eliminano i due rischi più grossi con due prove isolate, poi `aracnod` a fette verticali e infine il menù.

## Decisioni architetturali
- **Utente dedicato `aracno` + regola polkit**, non root. Verificato sul sorgente di systemd v255: freeze e thaw passano a polkit `unit` e `verb` (`stop`/`start`), e anche root senza `CAP_SYS_ADMIN` passa da polkit. La regola permette solo `start` e `stop` sulle sole unit `systemd-nspawn@*.service`.
- **Elenco dei tentacoli da systemd-machined** (`ListImages`): `/var/lib/machines` è 0700 root e `aracnod` non deve leggerlo.
- **Rust**, workspace in `aracno/`: `zbus` 6.2, `zbus_polkit` 6.0, `tokio` 1.54, `thiserror` 2.0, `gtk4` 0.11, `gtk4-layer-shell` 0.8 (versioni stabili su crates.io al 2026-11-01). Il crate di layer-shell richiede la libreria C ≥ 1.0: Debian trixie ha 1.0.4, Pop!_OS 24.04 non ce l'ha: per lo sviluppo è compilata dai sorgenti v1.0.4 in `~/.local` (build con `PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig`, avvio con `LD_LIBRARY_PATH=$HOME/.local/lib/x86_64-linux-gnu`).
- **Installazione di sviluppo** sul PC con uno script lanciato dall'utente (`prototype/11-install-aracnod.sh`), in percorsi locali: `/usr/local/libexec`, `/etc/dbus-1/system.d`, `/etc/polkit-1/rules.d`, `/etc/systemd/system`. I pacchetti `.deb` e Arch, con i percorsi in `/usr/share`, arrivano con l'ISO.
- Le decisioni confermate dalle prove vanno registrate in **ADR-0008** (task 3).

## Grafo delle dipendenze
```
T1 prova polkit ──► T3 ADR-0008 ──► T4 proto ──► T5 ListTentacles ──► T6 Switch ──► T7 Stop + sicurezza
T2 prova layer-shell ─────────────────────────────────────────────────► T8 menù base ──► T9 raggiera + switch ──► T10 grafica ──► T11 aggiornamenti live + i18n
                                                    (T8 richiede anche T5)
```
T1 e T2 sono indipendenti. Il menù (T8) ha bisogno almeno di `ListTentacles` (T5).

## Fasi
1. **Prove dei rischi**: T1, T2. Checkpoint A.
2. **`aracnod`**: T3–T7. Checkpoint B (O1–O6 della spec).
3. **`aracno-menu`**: T8–T11. Checkpoint C (M1–M5 della spec).

## Rischi
| Rischio | Impatto | Mitigazione |
|---|---|---|
| La regola polkit non viene applicata a freeze e thaw come atteso | Alto: cambia il modello di sicurezza | T1 lo prova per primo con `busctl`, prima di scrivere il Rust |
| `ListImages` non è permesso a un utente non privilegiato | Medio | Verificato in T1; in alternativa `ListUnitsByPatterns` su `systemd-nspawn@*.service` |
| COSMIC non concede la tastiera esclusiva a layer-shell, o la libreria non si compila su Pop | Alto per il menù | T2 lo prova da solo; il ripiego è la finestra a schermo intero, già previsto dalla spec |
| Una policy D-Bus sbagliata espone metodi | Alto | Test negativi O3 e O4; `busctl` lanciato come `nobody` |
| Dipendenze Rust con vulnerabilità | Medio | `cargo audit` e `cargo deny` in T7, `Cargo.lock` nel repo |

## Domande aperte
Nessuna per ora. Se le prove T1 e T2 smentiscono le ipotesi, il piano si ferma e si rivede.
