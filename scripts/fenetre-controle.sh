#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# FENÊTRE DU CONTRÔLE APRÈS PUBLICATION — résiste aux retards du cron GitHub
# (20/11/2026, feu vert de Jean-Michel : « Oui, feu vert »).
#
# Constats : le contrôle « 14h00 » tourne en réalité vers 22h NC ; le samedi il
# passe minuit et croyait contrôler DIMANCHE (« rien à contrôler », faux vert) ;
# le jeudi 19/11 il a contrôlé une publication partie 7 h en retard.
#
#   jour
#       jour_controle = date NC de (maintenant − 6 h) : un run de 01h24 dimanche
#       contrôle bien le samedi. Écrit today_nc et dow.
#   publication <workflow.yml> <AAAA-MM-JJ> <HHMM verdict>
#       la publication du jour est-elle TERMINÉE ? Tant qu'elle ne l'est pas et
#       qu'il est avant <HHMM verdict> le jour même, attente=true : ce run sort
#       à vide et un déclenchement suivant contrôlera. Après cette heure, le
#       contrôle se fait quoi qu'il arrive (et échoue si rien n'est parti).
#   verdict <format> <AAAA-MM-JJ> existe|poser
#       tag controle-<format>-<date> : un seul verdict par publication, les
#       déclenchements suivants s'arrêtent (pas de double clôture, pas de
#       double alerte).
# Essai : CONTROLE_ESSAI=1 → tags « essai-controle-… », CONTROLE_MAINTENANT=<date ISO> simule l'heure.
# ---------------------------------------------------------------------------
set -uo pipefail
NC="Pacific/Noumea"
sortie() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1" >> "$GITHUB_OUTPUT"; echo "→ $1"; }
maintenant() { if [ "${CONTROLE_ESSAI:-}" = "1" ] && [ -n "${CONTROLE_MAINTENANT:-}" ]; then date -d "$CONTROLE_MAINTENANT" +%s; else date +%s; fi; }
MODE="${1:?jour, publication ou verdict}"

case "$MODE" in
jour)
  T=$(( $(maintenant) - 21600 ))
  sortie "today_nc=$(TZ=$NC date -d "@$T" +%Y-%m-%d)"
  sortie "dow=$(TZ=$NC date -d "@$T" +%u)"
  [ "$(TZ=$NC date -d "@$(maintenant)" +%Y-%m-%d)" != "$(TZ=$NC date -d "@$T" +%Y-%m-%d)" ] && \
    echo "::notice title=Contrôle::run arrivé après minuit NC (retard du cron) — c'est la publication de la VEILLE qui est contrôlée."
  exit 0
  ;;
publication)
  WF="${2:?workflow}"; JOUR="${3:?date}"; VERDICT="${4:?HHMM verdict}"
  REPO="${GITHUB_REPOSITORY:-Blaisejm/perfecoconsulting}"
  AUTH=(); [ -n "${GH_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $GH_TOKEN")
  CODE=$(curl -s "${AUTH[@]}" -o /tmp/runs-pub.json -w "%{http_code}" "https://api.github.com/repos/$REPO/actions/workflows/$WF/runs?per_page=30")
  if [ "$CODE" != "200" ]; then
    echo "::warning title=Contrôle::état de $WF illisible (HTTP $CODE) — contrôle fait sans attendre."
    sortie "etat_publication=inconnu"; sortie "attente=false"; exit 0
  fi
  ETAT=absente
  for L in $(jq -r '.workflow_runs[] | "\(.created_at)|\(.status)|\(.conclusion)"' /tmp/runs-pub.json); do
    D=$(TZ=$NC date -d "${L%%|*}" +%Y-%m-%d); [ "$D" = "$JOUR" ] || continue
    R="${L#*|}"
    case "$R" in
      "completed|success"|"completed|failure") ETAT=terminee; break ;;
      completed*) ;;                     # annulé (doublon de déclenchement) ou sauté : ne compte pas
      *) ETAT=en_cours ;;
    esac
  done
  sortie "etat_publication=$ETAT"
  M=$(maintenant)
  if [ "$ETAT" != "terminee" ] && [ "$(TZ=$NC date -d "@$M" +%Y-%m-%d)" = "$JOUR" ] && [ "$((10#$(TZ=$NC date -d "@$M" +%H%M)))" -lt "$((10#$VERDICT))" ]; then
    echo "::notice title=Contrôle::publication du $JOUR encore $ETAT ($WF) — contrôle remis au déclenchement suivant (verdict au plus tard après ${VERDICT:0:2}h${VERDICT:2:2} NC)."
    sortie "attente=true"; exit 0
  fi
  sortie "attente=false"; exit 0
  ;;
verdict)
  FMT="${2:?format}"; JOUR="${3:?date}"; ACTION="${4:?existe ou poser}"
  PREFIXE="controle"; [ "${CONTROLE_ESSAI:-}" = "1" ] && PREFIXE="essai-controle"
  TAG="$PREFIXE-$FMT-$JOUR"
  if [ "$ACTION" = "existe" ]; then
    if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
      echo "::notice title=Contrôle::verdict déjà rendu pour $FMT du $JOUR ($TAG) — rien à refaire."
      sortie "verdict_rendu=true"; exit 0
    fi
    sortie "verdict_rendu=false"; exit 0
  fi
  git tag "$TAG" 2>/dev/null || true
  git push -q origin "refs/tags/$TAG" 2>/dev/null && echo "Verdict noté : $TAG." || echo "::warning title=Contrôle::tag $TAG non posé (déjà là, ou droits) — un déclenchement suivant refera le contrôle."
  exit 0
  ;;
*) echo "::error::mode « $MODE » inconnu."; exit 1 ;;
esac
