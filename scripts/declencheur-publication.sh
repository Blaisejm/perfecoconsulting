#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# DÉCLENCHEUR DE LA PUBLICATION DE 11h00 NC (25/11/2026 — Jean-Michel : « Oui, fiabilise 11h00 »)
#
# Constat : le cron GitHub part avec plusieurs heures de retard (jeudi 19/11 ~18h, vendredi
# 20/11 ~16h, mardi 24/11 15h59). La routine cloud claude.ai « declencheur-publication-cloud »
# tourne vers 10h45 NC, PC éteint, et pousse automation-agent/declencheur-publication.json ;
# ce push lance .github/workflows/declencheur-publication.yml, qui lance à son tour (workflow_dispatch,
# GITHUB_TOKEN) le ou les workflows de publication du jour. Ceux-ci gardent TOUTES leurs gardes :
# créneau suspendu, fraîcheur de la file, attente de 11h00, tag anti-doublon pub-<jour>-AAAA-MM-JJ.
# Les crons GitHub restent en place comme rattrapage : le premier run arrivé pose le tag, les
# autres s'arrêtent. Aucune double publication possible.
#
# Usage :
#   scripts/declencheur-publication.sh liste [AAAA-MM-JJ]
#       Affiche, une par ligne, les fichiers de workflow à lancer pour cette date NC (défaut :
#       aujourd'hui NC). Rien si rien n'est à publier. Règles :
#         - mardi / jeudi / vendredi : automation-queue/<format>.json porte date_prevue = date
#           (couvre les décalages de férié : mardi → lundi, jeudi → mercredi, vendredi → samedi)
#           et le registre ne marque pas ce créneau « suspendu » ;
#         - samedi : la republication Facebook est lancée chaque samedi (elle décide seule si
#           elle republie : jeudi suspendu, samedi de veille reportée, etc.).
#   Variables d'essai : FILE_DIR (défaut automation-queue), REGISTRE (défaut
#   automation-agent/publications.json).
# ---------------------------------------------------------------------------
set -uo pipefail
MODE="${1:?liste}"
D="${2:-$(TZ=Pacific/Noumea date +%Y-%m-%d)}"
FILE_DIR="${FILE_DIR:-automation-queue}"
REGISTRE="${REGISTRE:-automation-agent/publications.json}"
[ "$MODE" = "liste" ] || { echo "mode « $MODE » inconnu (liste)" >&2; exit 2; }
date -d "$D" +%F >/dev/null 2>&1 || { echo "date invalide : $D" >&2; exit 2; }

python3 - "$D" "$FILE_DIR" "$REGISTRE" <<'PY'
import json, sys, datetime, os
d, qdir, reg_path = sys.argv[1], sys.argv[2], sys.argv[3]
WF = {
    'mardi': 'publish-mardi-carrousel.yml',
    'jeudi': 'publish-jeudi-post-court.yml',
    'vendredi': 'publish-vendredi-veille-eco.yml',
    'samedi': 'publish-samedi-republication-facebook.yml',
}
try:
    reg = json.load(open(reg_path, encoding='utf-8-sig')).get('publications', [])
except Exception as e:
    print(f"registre illisible ({e}) : aucune garde « suspendu » appliquée ici (les workflows l'appliquent)", file=sys.stderr)
    reg = []
def suspendu(fmt):
    return any(p.get('date_nc') == d and p.get('format') == fmt and p.get('statut') == 'suspendu' for p in reg)
sortie = []
for fmt in ('mardi', 'jeudi', 'vendredi'):
    f = os.path.join(qdir, f'{fmt}.json')
    try:
        dp = json.load(open(f, encoding='utf-8-sig')).get('date_prevue')
    except Exception:
        continue
    if dp == d and not suspendu(fmt):
        sortie.append(WF[fmt])
if datetime.date.fromisoformat(d).isoweekday() == 6:
    sortie.append(WF['samedi'])
for w in sortie:
    print(w)
PY
