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
  # ── RELAIS DE VEILLEURS (22/11/2026, accord de Jean-Michel : « Oui, le relais ») ──
  # Même les créneaux du matin partent avec 5 h de retard (samedi 21/11 : publié à 12h45).
  # Un workflow_dispatch, lui, démarre en quelques secondes. Des crons d'ENTRÉE la veille
  # au soir lancent donc un veilleur : s'il est à plus de 5 h 40 de l'heure cible, il dort
  # 5 h 30 puis se relance lui-même (workflow_dispatch, GITHUB_TOKEN, actions: write) ;
  # sinon il attend l'heure cible et publie. Aucun jeton ni compte externe.
  # Activé par CRENEAU_JOUR_SEMAINE (1=lundi … 7=dimanche, jour NC de la publication) :
  # un run lancé un autre jour vise la prochaine date NC qui porte ce jour.
  D="$DATE_NC"
  if [ -n "${CRENEAU_JOUR_SEMAINE:-}" ] && [ "$(TZ=$NC date +%u)" != "$CRENEAU_JOUR_SEMAINE" ]; then
    for k in 1 2 3 4 5 6; do
      D=$(TZ=$NC date -d "$DATE_NC +$k day" +%Y-%m-%d)
      [ "$(TZ=$NC date -d "$D 12:00" +%u)" = "$CRENEAU_JOUR_SEMAINE" ] && break
    done
  fi
  ATTENTE=$(( $(TZ=$NC date -d "$D ${CIBLE:0:2}:${CIBLE:2:2}" +%s) - $(date +%s) ))
  if [ -n "${CRENEAU_JOUR_SEMAINE:-}" ] && { [ "$D" != "$DATE_NC" ] || [ "$ATTENTE" -gt 20400 ]; }; then
    TAG="$PREFIXE-$JOUR-$D"
    if tag_existe; then sortie "suite=deja"; exit 0; fi
    if [ "$ATTENTE" -le 20400 ]; then
      echo "Veilleur : publication du $D à ${CIBLE:0:2}h${CIBLE:2:2} NC dans ${ATTENTE} s — attente sur place."
      [ "${CRENEAU_ESSAI:-}" = "1" ] && ATTENTE=$(( ATTENTE > 10 ? 10 : ATTENTE ))
      [ "$ATTENTE" -gt 0 ] && sleep "$ATTENTE"
      if tag_existe; then sortie "suite=deja"; exit 0; fi
      sortie "suite=publier"; exit 0
    fi
    SOMMEIL=19800; [ "${CRENEAU_ESSAI:-}" = "1" ] && SOMMEIL=5
    echo "Veilleur : publication du $D à ${CIBLE:0:2}h${CIBLE:2:2} NC dans ${ATTENTE} s (> 5 h 40) — sommeil de ${SOMMEIL} s, puis relance."
    sleep "$SOMMEIL"
    if tag_existe; then sortie "suite=deja"; exit 0; fi
    WF=$(echo "${GITHUB_WORKFLOW_REF:-}" | sed -n 's#.*/\.github/workflows/\([^@]*\)@.*#\1#p')
    if [ "${CRENEAU_ESSAI:-}" = "1" ] && [ "${CRENEAU_ESSAI_RELANCE:-}" != "1" ]; then
      echo "::notice title=Veilleur $JOUR::relance SIMULÉE (essai) de ${WF:-?} — rien n'est déclenché."
      sortie "suite=relais"; exit 0
    fi
    CODE=$(curl -s -o /tmp/relais.txt -w "%{http_code}" -X POST \
      -H "Authorization: Bearer ${GH_TOKEN:-}" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY:-Blaisejm/perfecoconsulting}/actions/workflows/$WF/dispatches" \
      -d '{"ref":"main"}')
    if [ "$CODE" = "204" ]; then
      echo "::notice title=Veilleur $JOUR::relais lancé ($WF, workflow_dispatch) — vise le $D à ${CIBLE:0:2}h${CIBLE:2:2} NC."
      sortie "suite=relais"; exit 0
    fi
    echo "::error title=Veilleur $JOUR::relance impossible ($WF, HTTP $CODE $(head -c 200 /tmp/relais.txt)) — les créneaux du matin restent en secours."
    sortie "suite=relais_rompu"; exit 1
  fi
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
