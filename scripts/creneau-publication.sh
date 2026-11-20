#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# CRÉNEAU DE PUBLICATION — résiste aux retards du cron GitHub (20/11/2026,
# feu vert de Jean-Michel : « Oui, feu vert »).
#
# Constat : les crons de 00:00 UTC partent avec 5 à 7 h de retard (jeudi 19/11
# publié vers 18h NC au lieu de 11h). Chaque workflow de publication a donc
# PLUSIEURS déclenchements, à des minutes peu chargées, dès avant l'heure cible.
# Ce script décide, pour chacun, ce qu'il doit faire.
#
# Usage :
#   scripts/creneau-publication.sh attendre <jour> <HHMM cible> <HHMM limite>
#       - déjà publié aujourd'hui (tag présent)   → suite=deja      (exit 0)
#       - avant l'heure cible                     → ATTEND sur place, puis suite=publier
#       - entre la cible et la limite             → suite=publier   (rattrapage)
#       - après la limite                         → suite=hors_delai (exit 1 → issue « alerte »)
#   scripts/creneau-publication.sh prendre <jour>
#       pousse le tag pub-<jour>-AAAA-MM-JJ JUSTE AVANT l'envoi. Le serveur refuse
#       un tag existant : un seul run publie, les autres sortent en suite=deja.
#
# Le tag est posé AVANT l'envoi, pas après : un run qui meurt pendant l'envoi
# ne laisse jamais un second run republier (pas de doublon ; l'issue « alerte »
# signale l'échec). Le jour est celui de la Nouvelle-Calédonie.
#
# Essai : CRENEAU_ESSAI=1 → tags « essai-pub-… », attente plafonnée à 10 s,
#         CRENEAU_HEURE=HHMM simule l'heure NC.
# ---------------------------------------------------------------------------
set -uo pipefail
MODE="${1:?attendre ou prendre}"
JOUR="${2:?jour de diffusion (mardi, jeudi, vendredi, samedi)}"
NC="Pacific/Noumea"
DATE_NC=$(TZ=$NC date +%Y-%m-%d)
PREFIXE="pub"; [ "${CRENEAU_ESSAI:-}" = "1" ] && PREFIXE="essai-pub"
TAG="$PREFIXE-$JOUR-$DATE_NC"
sortie() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1" >> "$GITHUB_OUTPUT"; echo "→ $1"; }
heure() { if [ "${CRENEAU_ESSAI:-}" = "1" ] && [ -n "${CRENEAU_HEURE:-}" ]; then echo "$CRENEAU_HEURE"; else TZ=$NC date +%H%M; fi; }
tag_existe() { git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; }
sortie "tag=$TAG"

case "$MODE" in
attendre)
  CIBLE="${3:?HHMM cible}"; LIMITE="${4:?HHMM limite}"
  if tag_existe; then
    echo "::notice title=Créneau $JOUR::déjà publié aujourd'hui ($TAG présent) — ce déclenchement de secours s'arrête là."
    sortie "suite=deja"; exit 0
  fi
  H=$(heure)
  if [ "$((10#$H))" -lt "$((10#$CIBLE))" ]; then
    MAINTENANT=$(date +%s)
    CIBLE_S=$(TZ=$NC date -d "$DATE_NC ${CIBLE:0:2}:${CIBLE:2:2}" +%s)
    ATTENTE=$((CIBLE_S - MAINTENANT))
    [ "${CRENEAU_ESSAI:-}" = "1" ] && ATTENTE=$(( ATTENTE > 10 ? 10 : (ATTENTE < 0 ? 0 : ATTENTE) ))
    if [ "$ATTENTE" -gt 20400 ]; then
      # 5 h 40 : au-delà, le job (6 h maximum) n'irait pas au bout. Un déclenchement plus tardif prendra le relais.
      echo "::notice title=Créneau $JOUR::arrivé à ${H:0:2}h${H:2:2} NC, trop tôt pour attendre ${CIBLE:0:2}h${CIBLE:2:2} — un déclenchement suivant publiera."
      sortie "suite=trop_tot"; exit 0
    fi
    echo "Arrivé à ${H:0:2}h${H:2:2} NC — attente de ${CIBLE:0:2}h${CIBLE:2:2} NC (${ATTENTE} s)."
    [ "$ATTENTE" -gt 0 ] && sleep "$ATTENTE"
    if tag_existe; then sortie "suite=deja"; exit 0; fi
    sortie "suite=publier"; exit 0
  fi
  if [ "$((10#$H))" -gt "$((10#$LIMITE))" ]; then
    echo "::error title=Créneau $JOUR::aucun déclenchement n'a pu publier avant ${LIMITE:0:2}h${LIMITE:2:2} NC (il est ${H:0:2}h${H:2:2}) — retard du cron GitHub. RIEN n'est publié si tard : à reprogrammer à la main."
    sortie "suite=hors_delai"; exit 1
  fi
  [ "$((10#$H))" -gt "$((10#$CIBLE))" ] && echo "::notice title=Créneau $JOUR::rattrapage — publication à ${H:0:2}h${H:2:2} NC au lieu de ${CIBLE:0:2}h${CIBLE:2:2} (retard du cron GitHub)."
  sortie "suite=publier"; exit 0
  ;;
prendre)
  # Test AVANT de pousser : repousser un tag identique (même commit) répond « up-to-date »
  # sans erreur — sans ce test, un second run se croirait seul et publierait en double.
  if tag_existe; then
    echo "::notice title=Créneau $JOUR::$TAG déjà posé par un autre run — pas de second envoi."
    sortie "suite=deja"; exit 0
  fi
  git tag "$TAG" 2>/dev/null || true
  if git push -q origin "refs/tags/$TAG" 2>/tmp/tag-err.txt; then
    echo "✅ Tag $TAG posé : ce run est le seul à publier aujourd'hui."
    sortie "suite=publier"; exit 0
  fi
  if tag_existe; then
    echo "::notice title=Créneau $JOUR::$TAG déjà posé par un autre run — pas de second envoi."
    sortie "suite=deja"; exit 0
  fi
  echo "::error title=Créneau $JOUR::impossible de poser $TAG ($(head -c 300 /tmp/tag-err.txt)) — rien n'est envoyé (permissions contents: write ?)."
  sortie "suite=erreur"; exit 1
  ;;
*) echo "::error::mode « $MODE » inconnu (attendre ou prendre)."; exit 1 ;;
esac
