#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# FACEBOOK EN DIRECT AVEC L'IMAGE CARRÉE, REPLI MAKE SI ÉCHEC AVANT PUBLICATION
# (22/11/2026, demande de Jean-Michel : « agrandir le logo et adapter les images …
# améliorer les parutions notamment FB » — points A-2026-11-22-08 et 09).
#
# Make envoie la MÊME image à tous ses canaux : pour donner à Facebook une image
# carrée 1200×1200 (LinkedIn garde le 4:5), Facebook est publié ici, en direct par
# l'API Graph, et l'appel Make du jour porte le suffixe -NOFB (route Facebook
# bloquée, mécanisme déjà éprouvé le jeudi).
#
# Usage : scripts/facebook-direct-ou-repli.sh <file.json> [--dry-run]
#   lit .social_post.message, .social_post.facebook_image_url (sinon image_url), .semaine
# Codes : 0 publié (direct ou repli) ; 1 état incertain ou repli en échec (alerte).
# ---------------------------------------------------------------------------
set -uo pipefail
FILE="${1:?fichier de file manquant}"
MODE="${2:-}"
RC=0
bash scripts/facebook-photo.sh "$FILE" $MODE || RC=$?
[ "$RC" = "0" ] && exit 0
if [ "$RC" != "2" ]; then
  echo "::error title=Facebook direct::état incertain (code $RC) — PAS de repli, vérifier la Page avant tout nouvel envoi."
  exit 1
fi
echo "::warning title=Facebook direct::échec avant publication — repli sur Make (FBONLY, image carrée)."
[ "$MODE" = "--dry-run" ] && { echo "(essai) le repli Make serait appelé ici — rien n'est envoyé."; exit 0; }
[ -n "${MAKE_WEBHOOK:-}" ] || { echo "::error::MAKE_WEBHOOK absent : repli impossible."; exit 1; }
MESSAGE=$(jq -r '.social_post.message' "$FILE")
IMAGE=$(jq -r '.social_post.facebook_image_url // .social_post.image_url' "$FILE")
SEMAINE=$(jq -r '.semaine' "$FILE")
CODE=$(curl -s -o /tmp/repli.txt -w "%{http_code}" -X POST "$MAKE_WEBHOOK" \
  --data-urlencode "message=$MESSAGE" --data-urlencode "image_url=$IMAGE" --data-urlencode "semaine=${SEMAINE}-FBONLY")
if [ "$CODE" = "200" ]; then echo "::notice title=Repli Make::Facebook envoyé par Make (FBONLY) — vérification par check-apres-publication."; exit 0; fi
echo "::error title=Repli Make::HTTP $CODE $(head -c 200 /tmp/repli.txt) — Facebook n'a rien reçu."
exit 1
