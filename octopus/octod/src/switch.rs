//! Logica pura dello switch: quali operazioni fare, in che ordine. Niente D-Bus qui.
//! Stessa sequenza di `octo switch` (prototype/octo): prima si congelano gli altri
//! attivi, poi si scongela o si avvia il tentacolo scelto.

use octopus_proto::{TentacleName, TentacleState};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Step {
    Freeze(TentacleName),
    Thaw(TentacleName),
    Start(TentacleName),
}

/// Piano dello switch verso `target`, dato lo stato attuale di tutti i tentacoli.
/// `None` se `target` non è tra i tentacoli conosciuti.
pub fn plan(all: &[(TentacleName, TentacleState)], target: &TentacleName) -> Option<Vec<Step>> {
    let (_, stato) = all.iter().find(|(n, _)| n == target)?;
    let mut passi: Vec<Step> = all
        .iter()
        .filter(|(n, s)| n != target && *s == TentacleState::Active)
        .map(|(n, _)| Step::Freeze(n.clone()))
        .collect();
    match stato {
        TentacleState::Frozen => passi.push(Step::Thaw(target.clone())),
        TentacleState::Off => passi.push(Step::Start(target.clone())),
        TentacleState::Active => {}
    }
    Some(passi)
}

#[cfg(test)]
mod tests {
    use super::*;
    use TentacleState::*;

    fn n(s: &str) -> TentacleName {
        TentacleName::try_from(s).unwrap()
    }

    #[test]
    fn verso_congelato_congela_gli_altri_poi_scongela() {
        let all = [(n("arch"), Frozen), (n("debian"), Active)];
        assert_eq!(
            plan(&all, &n("arch")),
            Some(vec![Step::Freeze(n("debian")), Step::Thaw(n("arch"))])
        );
    }

    #[test]
    fn verso_spento_congela_gli_altri_poi_avvia() {
        let all = [(n("arch"), Off), (n("debian"), Active)];
        assert_eq!(
            plan(&all, &n("arch")),
            Some(vec![Step::Freeze(n("debian")), Step::Start(n("arch"))])
        );
    }

    #[test]
    fn verso_gia_attivo_congela_solo_gli_altri_attivi() {
        let all = [
            (n("arch"), Active),
            (n("debian"), Active),
            (n("fedora"), Frozen),
            (n("void"), Off),
        ];
        assert_eq!(
            plan(&all, &n("arch")),
            Some(vec![Step::Freeze(n("debian"))])
        );
    }

    #[test]
    fn gia_attivo_e_unico_non_fa_nulla() {
        let all = [(n("arch"), Active), (n("debian"), Frozen)];
        assert_eq!(plan(&all, &n("arch")), Some(vec![]));
    }

    #[test]
    fn tentacolo_sconosciuto() {
        let all = [(n("debian"), Active)];
        assert_eq!(plan(&all, &n("arch")), None);
    }

    #[test]
    fn i_congelamenti_vengono_sempre_prima() {
        let all = [(n("a"), Active), (n("b"), Off), (n("c"), Active)];
        let p = plan(&all, &n("b")).unwrap();
        assert_eq!(p.last(), Some(&Step::Start(n("b"))));
        assert!(p[..p.len() - 1]
            .iter()
            .all(|s| matches!(s, Step::Freeze(_))));
        assert_eq!(p.len(), 3);
    }
}
