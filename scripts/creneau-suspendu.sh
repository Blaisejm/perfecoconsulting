#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# CRÉNEAU SUSPENDU ? (23/11/2026 — Jean-Michel : « Pause 22/12 → 15/01 »)
#
# Usage : scripts/creneau-suspendu.sh <mardi|jeudi|vendredi> [AAAA-MM-JJ]
#   Code 0 : le registre (automation-agent/publications.json) porte, pour cette date (défaut :
#            aujourd'hui NC) et ce format, une échéance au statut « suspendu ». Le workflow
#            doit alors sortir NORMALEMENT, sans publier et sans erreur (pas d'issue « alerte »).
#   Code 1 : pas suspendu (ou registre illisible) : le workflow continue comme d'habitude.
# Sans cette garde, chaque créneau de la pause finissait en ::error (« date_prevue ne
# correspond pas ») et ouvrait une issue « alerte » à chaque tentative.
# ---------------------------------------------------------------------------
FMT="${1:?format manquant}"
JOUR="${2:-$(TZ="Pacific/Noumea" date +%Y-%m-%d)}"
python3 - "$FMT" "$JOUR" <<'PY'
import json, sys
fmt, jour = sys.argv[1], sys.argv[2]
try:
    reg = json.load(open('automation-agent/publications.json', encoding='utf-8-sig'))
except Exception as e:
    print(f"Registre illisible ({e}) : créneau considéré comme actif."); sys.exit(1)
for p in reg.get('publications', []):
    if p.get('date_nc') == jour and p.get('format') == fmt and p.get('statut') == 'suspendu':
        print(f"::notice title=Créneau suspendu::{p.get('id')} est SUSPENDU (registre) — rien à publier, sortie normale.")
        sys.exit(0)
sys.exit(1)
PY
