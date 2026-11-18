#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# GARDE AVANT TOUT APPEL AU WEBHOOK MAKE (diffusion 100 % cloud, étape 2, 19/11/2026)
#
# POURQUOI : le 29/10/2026, un appel au webhook avec un corps vide a fait
# désactiver le scénario 6916780 par Make (isinvalid), et toutes les publications
# suivantes sont parties dans le vide. Un appel envoyé alors que le scénario est
# INACTIF est pire encore : Make le garde en file et le publiera au moment de la
# réactivation — hors calendrier.
#
# Usage : scripts/garde-make.sh <file.json>
#   lit .social_post.message et .social_post.image_url
#   env MAKE_API_TOKEN (facultatif : sans lui, l'état du scénario n'est pas vérifié)
#
# Sortie 0 : l'appel peut partir.  Sortie 1 : NE PAS appeler le webhook.
# La garde ne contrôle pas la date : l'étape « fraîcheur » de chaque workflow le fait déjà.
# ---------------------------------------------------------------------------
set -uo pipefail
FILE="${1:?fichier de file manquant}"
SCENARIO=6916780
API="https://eu1.make.com/api/v2"
KO=0
refus() { echo "::error title=Garde Make::$1"; KO=1; }

MESSAGE=$(jq -r '.social_post.message // empty' "$FILE" 2>/dev/null)
IMAGE_URL=$(jq -r '.social_post.image_url // empty' "$FILE" 2>/dev/null)

# 1. Message : présent et d'une longueur crédible (un post PerfEco fait des centaines de caractères).
if [ -z "$MESSAGE" ] || [ "$MESSAGE" = "null" ]; then
  refus ".social_post.message vide dans $FILE — appel annulé (un corps vide a fait désactiver le scénario le 29/10)."
elif [ "${#MESSAGE}" -lt 80 ]; then
  refus ".social_post.message ne fait que ${#MESSAGE} caractères dans $FILE — contenu suspect, appel annulé."
else
  echo "✅ Message : ${#MESSAGE} caractères."
fi

# 2. Image : répond 200 et est bien une image (un 404 Netlify = post sans visuel, ou rejet Make).
if [ -z "$IMAGE_URL" ] || [ "$IMAGE_URL" = "null" ]; then
  refus ".social_post.image_url vide dans $FILE."
else
  ENTETES=$(curl -s -L -o /dev/null -w "%{http_code} %{content_type}" "$IMAGE_URL")
  CODE=${ENTETES%% *}; TYPE=${ENTETES#* }
  case "$CODE:$TYPE" in
    200:image/*) echo "✅ Image : HTTP 200 ($TYPE) — $IMAGE_URL" ;;
    *) refus "image injoignable ou pas une image — HTTP $CODE, type « $TYPE » — $IMAGE_URL (site perfeco.nc redéployé ?)." ;;
  esac
fi

# 3. Scénario : actif et valide, sinon l'appel resterait en file et partirait hors calendrier.
if [ -z "${MAKE_API_TOKEN:-}" ]; then
  echo "::warning title=Garde Make::MAKE_API_TOKEN absent — état du scénario non vérifié."
else
  CODE=$(curl -s -o /tmp/garde-sc.json -w "%{http_code}" -H "Authorization: Token $MAKE_API_TOKEN" "$API/scenarios/$SCENARIO")
  if [ "$CODE" = "200" ]; then
    ACTIF=$(jq -r '.scenario.isActive' /tmp/garde-sc.json)
    INVALIDE=$(jq -r '.scenario.isinvalid' /tmp/garde-sc.json)
    if [ "$ACTIF" != "true" ] || [ "$INVALIDE" = "true" ]; then
      refus "scénario $SCENARIO isActive=$ACTIF isinvalid=$INVALIDE — appel annulé : il resterait en file et serait publié à la réactivation, hors calendrier. https://eu1.make.com/1970457/scenarios/$SCENARIO/edit"
    else
      echo "✅ Scénario $SCENARIO actif et valide."
    fi
  else
    # Un jeton de SURVEILLANCE en panne ne doit pas bloquer une publication par ailleurs saine.
    echo "::warning title=Garde Make::état du scénario illisible (HTTP $CODE) — appel autorisé quand même, à vérifier."
  fi
fi

[ "$KO" = "0" ] && echo "Garde Make : feu vert." || echo "Garde Make : appel REFUSÉ."
exit $KO
