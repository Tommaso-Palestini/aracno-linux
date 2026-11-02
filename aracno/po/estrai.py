#!/usr/bin/env python3
"""Estrae i testi da tradurre (chiamate tr("...")) dai sorgenti Rust in po/aracno.pot.

xgettext 0.21 (Pop!_OS 24.04) non conosce il Rust: lo tratta come C e si ferma su
'static e sugli apostrofi. Il supporto Rust arriva con gettext 0.24; fino ad allora
basta questo. Uso, dalla cartella aracno/:
    python3 po/estrai.py && msgmerge --update po/en.po po/aracno.pot
"""
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
CHIAMATA = re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"\s*,?\s*\)')


def main() -> int:
    voci: dict[str, list[str]] = {}
    for riga in (RADICE / "po" / "POTFILES").read_text().split():
        testo = (RADICE / riga).read_text(encoding="utf-8")
        for m in CHIAMATA.finditer(testo):
            n = testo.count("\n", 0, m.start()) + 1
            voci.setdefault(m.group(1), []).append(f"{riga}:{n}")
    out = [
        '# Testi di Aracno da tradurre. Generato da po/estrai.py: non modificare a mano.',
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: aracno\\n"',
        '"Report-Msgid-Bugs-To: https://github.com/Tommaso-Palestini/aracno-linux/issues\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        "",
    ]
    for testo, dove in voci.items():
        out.append("#: " + " ".join(dove))
        if "{}" in testo:
            out.append("#. {} è il nome di un filo, da lasciare com'è")
        out += [f'msgid "{testo}"', 'msgstr ""', ""]
    (RADICE / "po" / "aracno.pot").write_text("\n".join(out), encoding="utf-8")
    print(f"{len(voci)} testi in po/aracno.pot")
    return 0


if __name__ == "__main__":
    sys.exit(main())
