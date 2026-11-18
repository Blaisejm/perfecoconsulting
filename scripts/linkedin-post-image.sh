#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PUBLIE UN POST À IMAGE UNIQUE SUR LE PROFIL LINKEDIN PERSO, SANS MAKE
# (diffusion 100 % cloud, étape 3, 19/11/2026 — jeudi et vendredi ; le mardi a
# son propre script, linkedin-carrousel-pdf.sh).
#
# Usage : scripts/linkedin-post-image.sh <file.json> <PUBLISHED|DRAFT|--dry-run> [--supprimer-apres]
#   lit .social_post.message et .social_post.image_url (les champs envoyés à Make)
#   --dry-run              : contrôles + requête construite, RIEN n'est envoyé à LinkedIn
#   DRAFT --supprimer-apres : essai complet (upload + brouillon invisible), puis suppression
#
# CODES DE SORTIE (même contrat que linkedin-carrousel-pdf.sh) :
#   0  post créé (201) — ou essai réussi
#   2  échec AVANT la création du post → le repli Make peut partir sans doublon
#   1  création tentée sans 201 → état incertain, PAS de repli
# ---------------------------------------------------------------------------
set -uo pipefail
FILE="${1:?fichier de file manquant}"
ETAT="${2:?PUBLISHED, DRAFT ou --dry-run}"
SUPPRIMER="${3:-}"
MEMBER_URN="urn:li:person:e0QUppRUQ8"
CAL="automation-agent/calendrier.json"
TMP="$(mktemp -d)"
avant() { echo "::error title=LinkedIn perso direct::$1"; exit 2; }

[ -n "${LINKEDIN_TOKEN:-}" ] || avant "LINKEDIN_TOKEN vide."
case "$ETAT" in PUBLISHED|DRAFT|--dry-run) ;; *) avant "état « $ETAT » inconnu." ;; esac
API_VERSION=$(jq -r '.linkedin.api_version // empty' "$CAL" 2>/dev/null)
[ -n "$API_VERSION" ] || avant "aucune version d'API (calendrier.json → .linkedin.api_version)."
MESSAGE=$(jq -r '.social_post.message // empty' "$FILE")
IMAGE_URL=$(jq -r '.social_post.image_url // empty' "$FILE")
[ -n "$MESSAGE" ] && [ "${#MESSAGE}" -ge 80 ] || avant ".social_post.message vide ou trop court (${#MESSAGE} car.) dans $FILE."
[ "${#MESSAGE}" -le 3000 ] || avant "message de ${#MESSAGE} caractères (> 3000, limite LinkedIn)."
[ -n "$IMAGE_URL" ] || avant ".social_post.image_url vide dans $FILE."

li() { curl -s "$@" -H "Authorization: Bearer $LINKEDIN_TOKEN" -H "LinkedIn-Version: $API_VERSION" -H "X-Restli-Protocol-Version: 2.0.0"; }

# 1. Jeton vivant ?
CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://api.linkedin.com/v2/userinfo" -H "Authorization: Bearer $LINKEDIN_TOKEN")
[ "$CODE" = "200" ] || avant "jeton LinkedIn refusé (userinfo HTTP $CODE) — renouvellement nécessaire."
echo "✅ Jeton LinkedIn vivant — API $API_VERSION — message ${#MESSAGE} caractères."

# 2. Image téléchargée ici, puis envoyée à LinkedIn (LinkedIn ne va pas la chercher).
CODE=$(curl -s -L -o "$TMP/image" -w "%{http_code} %{content_type}" "$IMAGE_URL")
case "$CODE" in "200 image/"*) echo "✅ Image : $CODE — $(wc -c < "$TMP/image") octets — $IMAGE_URL" ;; *) avant "image injoignable — $CODE — $IMAGE_URL" ;; esac

if [ "$ETAT" = "--dry-run" ]; then
  echo "Requêtes : POST /rest/images?action=initializeUpload → PUT de l'image → POST /rest/posts (content.media, PUBLISHED)"
  echo "::notice title=LinkedIn perso direct (essai)::tout est prêt — jeton, version $API_VERSION, image, message de ${#MESSAGE} caractères. RIEN n'a été envoyé."
  exit 0
fi

# 3. Upload.
jq -n --arg owner "$MEMBER_URN" '{initializeUploadRequest:{owner:$owner}}' > "$TMP/init.json"
CODE=$(li -o "$TMP/init-rep.json" -w "%{http_code}" -X POST "https://api.linkedin.com/rest/images?action=initializeUpload" \
  -H "Content-Type: application/json" --data-binary @"$TMP/init.json")
UPLOAD_URL=$(jq -r '.value.uploadUrl // empty' "$TMP/init-rep.json")
IMG_URN=$(jq -r '.value.image // empty' "$TMP/init-rep.json")
if [ -z "$UPLOAD_URL" ] || [ -z "$IMG_URN" ]; then
  cat "$TMP/init-rep.json"; echo
  grep -q NONEXISTENT_VERSION "$TMP/init-rep.json" && echo "::error::426 NONEXISTENT_VERSION — mettre à jour .linkedin.api_version dans $CAL."
  avant "initializeUpload (images) — HTTP $CODE."
fi
CODE=$(curl -s -o "$TMP/put.txt" -w "%{http_code}" -X PUT "$UPLOAD_URL" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @"$TMP/image")
case "$CODE" in 200|201) ;; *) cat "$TMP/put.txt"; avant "upload PUT de l'image — HTTP $CODE." ;; esac
echo "Image envoyée : $IMG_URN"

# 4. Attendre AVAILABLE (souvent immédiat ; 1 minute au plus).
ENC=$(jq -rn --arg u "$IMG_URN" '$u|@uri')
for t in $(seq 1 12); do
  li -o "$TMP/img.json" "https://api.linkedin.com/rest/images/$ENC"
  STATUT=$(jq -r '.status // empty' "$TMP/img.json")
  [ "$STATUT" = "AVAILABLE" ] && break
  [ "$STATUT" = "PROCESSING_FAILED" ] && avant "LinkedIn a refusé l'image (PROCESSING_FAILED)."
  sleep 5
done
[ "$STATUT" = "AVAILABLE" ] || avant "image toujours « ${STATUT:-inconnu} » après 1 minute."

# 5. Post. À partir d'ici, un échec n'autorise plus le repli.
jq -n --arg author "$MEMBER_URN" --arg msg "$MESSAGE" --arg img "$IMG_URN" --arg etat "$ETAT" \
  '{author:$author, commentary:$msg, visibility:"PUBLIC",
    distribution:{feedDistribution:"MAIN_FEED", targetEntities:[], thirdPartyDistributionChannels:[]},
    content:{media:{id:$img}}, lifecycleState:$etat, isReshareDisabledByAuthor:false}' > "$TMP/post.json"
CODE=$(li -o "$TMP/post-rep.txt" -D "$TMP/entetes.txt" -w "%{http_code}" -X POST "https://api.linkedin.com/rest/posts" \
  -H "Content-Type: application/json" --data-binary @"$TMP/post.json")
POST_URN=$(grep -i '^x-restli-id:' "$TMP/entetes.txt" | tr -d '\r' | awk '{print $2}')
if [ "$CODE" != "201" ]; then
  cat "$TMP/post-rep.txt"; echo
  echo "::error title=LinkedIn perso direct::création du post — HTTP $CODE. État incertain : vérifier le profil avant tout nouvel envoi (pas de repli automatique)."
  exit 1
fi
echo "::notice title=LinkedIn perso direct::post $ETAT créé ($POST_URN)."
[ -n "${GITHUB_OUTPUT:-}" ] && echo "li_post_urn=$POST_URN" >> "$GITHUB_OUTPUT"

if [ "$SUPPRIMER" = "--supprimer-apres" ]; then
  [ "$ETAT" = "DRAFT" ] || { echo "::error::--supprimer-apres refusé hors DRAFT."; exit 1; }
  E=$(jq -rn --arg u "$POST_URN" '$u|@uri')
  CODE=$(li -o /dev/null -w "%{http_code}" -X DELETE "https://api.linkedin.com/rest/posts/$E" -H "X-RestLi-Method: DELETE")
  case "$CODE" in 200|204) echo "::notice title=LinkedIn perso direct::brouillon d'essai supprimé (HTTP $CODE)." ;;
    *) echo "::warning title=LinkedIn perso direct::suppression du brouillon — HTTP $CODE (reste en brouillon, invisible)." ;; esac
fi
exit 0
