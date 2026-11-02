//! Se gtk4-layer-shell non è installata nel sistema (sul PC di sviluppo è in ~/.local,
//! compilata in T2), il binario deve sapere dove trovarla a runtime: si aggiunge un
//! rpath verso la sua cartella. Con la libreria di sistema (pacchetto Debian
//! libgtk4-layer-shell0, nell'ISO) non si aggiunge niente.

use std::process::Command;

fn main() {
    println!("cargo:rerun-if-env-changed=PKG_CONFIG_PATH");
    let Ok(out) = Command::new("pkg-config")
        .args(["--variable=libdir", "gtk4-layer-shell-0"])
        .output()
    else {
        return;
    };
    let libdir = String::from_utf8_lossy(&out.stdout).trim().to_owned();
    let di_sistema = libdir.is_empty() || libdir.starts_with("/usr/");
    if !di_sistema {
        println!("cargo:rustc-link-arg-bins=-Wl,-rpath,{libdir}");
    }
}
