#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PUBLIE UNE PHOTO + TEXTE SUR LA PAGE FACEBOOK PAR L'API GRAPH, SANS MAKE
# (diffusion 100 % cloud, étape 3, 19/11/2026 — feu vert de Jean-Michel :
# « lance l'étape 3 »). Make n'est plus qu'un REPLI pour Facebook.
#
# Usage : scripts/facebook-photo.sh <file.json> [--dry-run]
#   lit .social_post.message et .social_post.image_url (les champs envoyés à Make)
#   env FB_PAGE_TOKEN (jeton de PAGE, pages_manage_posts, sans expiration)
#   --dry-run : tous les contrôles (jeton, droits, Page, image, message) et la
#               requête construite — RIEN n'est envoyé à Facebook.
#
# CODES DE SORTIE — ils décident du repli Make dans le workflow appelant :
#   0  photo publiée (id reçu) — ou essai réussi
#   2  échec AVANT publication, ou refus explicite de Facebook (erreur Graph :
#      rien n'a été créé) → le repli Make peut partir sans risque de doublon
#   1  envoi parti sans réponse claire (réseau, 5xx) → état incertain, PAS de repli
# Écrit fb_post_id et fb_lien dans $GITHUB_OUTPUT.
# ---------------------------------------------------------------------------
set -uo pipefail
FILE="${1:?fichier de file manquant}"
MODE="${2:-}"
PAGE_ID="552866114572775"
GRAPH="https://graph.facebook.com/v19.0"
TMP="$(mktemp -d)"
avant() { echo "::error title=Facebook direct::$1"; exit 2; }
sortie() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1" >> "$GITHUB_OUTPUT"; }

[ -n "${FB_PAGE_TOKEN:-}" ] || avant "FB_PAGE_TOKEN vide."
MESSAGE=$(jq -r '.social_post.message // empty' "$FILE")
IMAGE_URL=$(jq -r '.social_post.image_url // empty' "$FILE")
[ -n "$MESSAGE" ] && [ "${#MESSAGE}" -ge 80 ] || avant ".social_post.message vide ou trop court (${#MESSAGE} car.) dans $FILE."
[ -n "$IMAGE_URL" ] || avant ".social_post.image_url vide dans $FILE."

# 1. Le jeton est-il bien celui de NOTRE Page, avec le droit de publier ?
CODE=$(curl -s -o "$TMP/dbg.json" -w "%{http_code}" -G "$GRAPH/debug_token" \
  --data-urlencode "input_token=$FB_PAGE_TOKEN" --data-urlencode "access_token=$FB_PAGE_TOKEN")
[ "$CODE" = "200" ] || avant "debug_token — HTTP $CODE ($(jq -c '.error.message // .' "$TMP/dbg.json" | head -c 300))."
VALIDE=$(jq -r '.data.is_valid' "$TMP/dbg.json")
PROFIL=$(jq -r '.data.profile_id // empty' "$TMP/dbg.json")
DROIT=$(jq -r '[.data.scopes[]?] | index("pages_manage_posts") != null' "$TMP/dbg.json")
[ "$VALIDE" = "true" ] || avant "jeton de Page INVALIDE (révoqué ? mot de passe Facebook changé ?) — à refaire."
[ "$PROFIL" = "$PAGE_ID" ] || avant "le jeton vise la Page $PROFIL, pas PerfEco Consulting NC ($PAGE_ID)."
[ "$DROIT" = "true" ] || avant "pages_manage_posts absent du jeton — publication directe impossible."
echo "✅ Jeton : Page $PAGE_ID, valide, pages_manage_posts présent."

# 2. L'image : Facebook la télécharge lui-même depuis l'URL ; un 404 = refus ou post sans visuel.
ENTETES=$(curl -s -L -o /dev/null -w "%{http_code} %{content_type}" "$IMAGE_URL")
case "$ENTETES" in "200 image/"*) echo "✅ Image : $ENTETES — $IMAGE_URL" ;; *) avant "image injoignable — $ENTETES — $IMAGE_URL" ;; esac

echo "Requête : POST $GRAPH/$PAGE_ID/photos  url=<image ci-dessus>  message=<${#MESSAGE} caractères>  published=true"
if [ "$MODE" = "--dry-run" ]; then
  echo "::notice title=Facebook direct (essai)::tout est prêt — jeton, droits, Page, image, message de ${#MESSAGE} caractères. RIEN n'a été envoyé."
  exit 0
fi

# 3. Publication. À partir d'ici, seul un refus EXPLICITE de Facebook autorise le repli.
CODE=$(curl -s --max-time 120 -o "$TMP/rep.json" -w "%{http_code}" -X POST "$GRAPH/$PAGE_ID/photos" \
  --data-urlencode "url=$IMAGE_URL" --data-urlencode "message=$MESSAGE" \
  --data-urlencode "published=true" --data-urlencode "access_token=$FB_PAGE_TOKEN")
POST_ID=$(jq -r '.post_id // .id // empty' "$TMP/rep.json" 2>/dev/null)
if [ "$CODE" = "200" ] && [ -n "$POST_ID" ]; then
  sortie "fb_post_id=$POST_ID"
  # Vérification réelle (leçon du 17/07 : « accepté » ≠ publié) : relire le post.
  sleep 5
  curl -s -o "$TMP/post.json" -G "$GRAPH/$POST_ID" --data-urlencode "fields=permalink_url,created_time,is_published" \
    --data-urlencode "access_token=$FB_PAGE_TOKEN"
  LIEN=$(jq -r '.permalink_url // empty' "$TMP/post.json")
  sortie "fb_lien=$LIEN"
  echo "::notice title=Facebook direct::publié ($POST_ID) — relu : $(jq -c '{created_time, is_published}' "$TMP/post.json") — $LIEN"
  exit 0
fi
ERREUR=$(jq -c '.error | {message, type, code, error_subcode}' "$TMP/rep.json" 2>/dev/null)
if [ "${CODE:0:1}" = "4" ] && [ -n "$ERREUR" ] && [ "$ERREUR" != "null" ]; then
  avant "Facebook a refusé la publication — HTTP $CODE $ERREUR. Rien n'a été créé : repli possible."
fi
echo "::error title=Facebook direct::réponse incertaine — HTTP $CODE $(head -c 300 "$TMP/rep.json"). Vérifier la Page AVANT tout nouvel envoi (pas de repli automatique)."
exit 1
