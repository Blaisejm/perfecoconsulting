#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# OUVRE (ou complète) UNE ISSUE « alerte » ASSIGNÉE À JEAN-MICHEL
# (diffusion 100 % cloud, étape 2, 19/11/2026 — remplace les brouillons Gmail
# des routines locales : une issue envoie un e-mail GitHub et se suit depuis
# l'application mobile, PC éteint).
#
# Usage : scripts/issue-alerte.sh "<titre>" "<corps markdown>"
#   Une issue ouverte du MÊME titre reçoit un commentaire au lieu d'un doublon :
#   mettre la date dans le titre pour une alerte par jour.
#   env GH_TOKEN (secrets.GITHUB_TOKEN, permission issues: write)
# Ne fait jamais échouer l'appelant : une alerte qui ne part pas est signalée, c'est tout.
# ---------------------------------------------------------------------------
set -u
TITRE="${1:?titre manquant}"
CORPS="${2:?corps manquant}"
LIEN="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
printf '%s\n\n---\nRun : %s\n' "$CORPS" "$LIEN" > /tmp/alerte-corps.md

gh label create alerte --color B60205 --description "Alerte de la diffusion PerfEco" >/dev/null 2>&1 || true
NUM=$(gh issue list --state open --label alerte --limit 50 --json number,title \
  --jq ".[] | select(.title == \"$TITRE\") | .number" 2>/dev/null | head -1)
if [ -n "$NUM" ]; then
  gh issue comment "$NUM" --body-file /tmp/alerte-corps.md >/dev/null \
    && echo "Alerte ajoutée en commentaire à l'issue #$NUM." \
    || echo "::warning::commentaire d'alerte impossible sur #$NUM."
else
  gh issue create --title "$TITRE" --label alerte --assignee Blaisejm --body-file /tmp/alerte-corps.md \
    || gh issue create --title "$TITRE" --label alerte --body-file /tmp/alerte-corps.md \
    || echo "::warning::création de l'issue d'alerte impossible (permission issues: write ?)."
fi
exit 0
