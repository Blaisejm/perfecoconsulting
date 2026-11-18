#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Publie le carrousel du mardi sur le profil LinkedIn perso en DOCUMENT PDF
# (post « document » : un vrai carrousel qu'on fait défiler).
#
# POURQUOI (décision de Jean-Michel du 18/11/2026, « Oui, passe le carrousel
# perso en PDF ») : en multi-images, LinkedIn affiche une mosaïque et recadre
# la couverture au centre. Sur le post I1 du 03/11 (W44), le titre « Le projet
# d'abord. L'argent ensuite. » s'est retrouvé collé au bord gauche.
# Voir la mémoire feedback_typographie_carrousel.md §8.
#
# Usage : scripts/linkedin-carrousel-pdf.sh <file.json> <PUBLISHED|DRAFT> [--supprimer-apres]
#   DRAFT + --supprimer-apres : essai complet sans rien laisser sur LinkedIn
#   (workflow essai-carrousel-pdf.yml).
#
# Entrées lues dans la file :
#   .linkedin_profil.message         texte du post (obligatoire)
#   .linkedin_profil.image_urls[]    slides PNG 01→06 (assemblées en PDF ici)
#   .linkedin_profil.pdf_url         FACULTATIF : PDF déjà exporté, utilisé tel quel
#   .linkedin_profil.titre_document  FACULTATIF : titre affiché sur le document
# Version d'API : automation-agent/calendrier.json → .linkedin.api_version
#
# CODES DE SORTIE — ils décident du repli dans publish-mardi-carrousel.yml :
#   0  post créé (HTTP 201)
#   2  échec AVANT toute tentative de création du post → rien n'existe sur
#      LinkedIn, le repli multi-images peut partir sans risque de doublon
#   1  la création du post a été tentée et n'a pas répondu 201 → état
#      incertain, PAS de repli automatique (risque de doublon), alerte
# ---------------------------------------------------------------------------
set -uo pipefail

FILE="${1:?fichier de file manquant}"
ETAT="${2:?PUBLISHED ou DRAFT}"
SUPPRIMER="${3:-}"
MEMBER_URN="urn:li:person:e0QUppRUQ8"
CAL="automation-agent/calendrier.json"
TMP="$(mktemp -d)"

avant() { echo "::error title=Carrousel PDF::$1"; exit 2; }

[ -n "${LINKEDIN_TOKEN:-}" ] || avant "LINKEDIN_TOKEN vide."
case "$ETAT" in PUBLISHED|DRAFT) ;; *) avant "état « $ETAT » inconnu (PUBLISHED ou DRAFT)." ;; esac

API_VERSION=$(jq -r '.linkedin.api_version // empty' "$CAL" 2>/dev/null)
[ -n "$API_VERSION" ] || API_VERSION=$(jq -r '.linkedin_api_version // empty' "$FILE")
[ -n "$API_VERSION" ] || avant "aucune version d'API LinkedIn (calendrier.json → .linkedin.api_version)."

MESSAGE=$(jq -r '.linkedin_profil.message // empty' "$FILE")
[ -n "$MESSAGE" ] || avant ".linkedin_profil.message vide dans $FILE."
SEMAINE=$(jq -r '.semaine // ""' "$FILE")
TITRE=$(jq -r '.linkedin_profil.titre_document // empty' "$FILE")
[ -n "$TITRE" ] || TITRE="PerfEco Consulting — carrousel ${SEMAINE}"
echo "API $API_VERSION — état $ETAT — titre « $TITRE » — message ${#MESSAGE} caractères"

# 1. Le PDF : fourni par la routine, sinon assemblé à partir des PNG.
PDF="$TMP/carrousel.pdf"
PDF_URL=$(jq -r '.linkedin_profil.pdf_url // empty' "$FILE")
if [ -n "$PDF_URL" ]; then
  CODE=$(curl -s -o "$PDF" -w "%{http_code}" "$PDF_URL")
  [ "$CODE" = "200" ] || avant "PDF injoignable ($PDF_URL) — HTTP $CODE."
  echo "PDF fourni par la file : $PDF_URL"
else
  i=0
  while read -r URL; do
    i=$((i+1))
    CODE=$(curl -s -o "$TMP/slide$(printf %02d $i).png" -w "%{http_code}" "$URL")
    [ "$CODE" = "200" ] || avant "slide $i injoignable ($URL) — HTTP $CODE."
  done < <(jq -r '.linkedin_profil.image_urls[]' "$FILE")
  [ "$i" -ge 2 ] || avant "moins de 2 slides dans .linkedin_profil.image_urls."
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v img2pdf >/dev/null; then
    python3 -m pip install --quiet --user --break-system-packages img2pdf >/dev/null 2>&1 \
      || python3 -m pip install --quiet --user img2pdf >/dev/null 2>&1 \
      || avant "installation d'img2pdf impossible."
  fi
  # img2pdf : PNG embarqués sans perte, une page par slide, au format exact de l'image.
  img2pdf "$TMP"/slide*.png -o "$PDF" || avant "assemblage PDF en échec."
  echo "PDF assemblé à partir de $i slides."
fi
TAILLE=$(wc -c < "$PDF")
head -c 5 "$PDF" | grep -q '%PDF-' || avant "le fichier obtenu n'est pas un PDF."
[ "$TAILLE" -lt 100000000 ] || avant "PDF de $TAILLE octets (> 100 Mo, limite LinkedIn)."
echo "PDF : $TAILLE octets"

li() { curl -s "$@" -H "Authorization: Bearer $LINKEDIN_TOKEN" -H "LinkedIn-Version: $API_VERSION" -H "X-Restli-Protocol-Version: 2.0.0"; }

# 2. Upload du document (Documents API).
jq -n --arg owner "$MEMBER_URN" '{initializeUploadRequest:{owner:$owner}}' > "$TMP/init.json"
CODE=$(li -o "$TMP/init-rep.json" -w "%{http_code}" -X POST "https://api.linkedin.com/rest/documents?action=initializeUpload" \
  -H "Content-Type: application/json" --data-binary @"$TMP/init.json")
UPLOAD_URL=$(jq -r '.value.uploadUrl // empty' "$TMP/init-rep.json")
DOC_URN=$(jq -r '.value.document // empty' "$TMP/init-rep.json")
if [ -z "$UPLOAD_URL" ] || [ -z "$DOC_URN" ]; then
  cat "$TMP/init-rep.json"; echo
  grep -q NONEXISTENT_VERSION "$TMP/init-rep.json" && echo "::error::426 NONEXISTENT_VERSION — mettre à jour .linkedin.api_version dans $CAL."
  avant "initializeUpload (documents) — HTTP $CODE."
fi
CODE=$(curl -s -o "$TMP/put.txt" -w "%{http_code}" -X PUT "$UPLOAD_URL" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @"$PDF")
case "$CODE" in 200|201) ;; *) cat "$TMP/put.txt"; avant "upload PUT du PDF — HTTP $CODE." ;; esac
echo "Document envoyé : $DOC_URN"

# 3. Attendre que LinkedIn ait traité le document (PROCESSING → AVAILABLE).
URN_ENC=$(jq -rn --arg u "$DOC_URN" '$u|@uri')
STATUT=""
for t in $(seq 1 24); do
  li -o "$TMP/doc.json" "https://api.linkedin.com/rest/documents/$URN_ENC"
  STATUT=$(jq -r '.status // empty' "$TMP/doc.json")
  [ "$STATUT" = "AVAILABLE" ] && break
  [ "$STATUT" = "PROCESSING_FAILED" ] && { cat "$TMP/doc.json"; avant "LinkedIn a refusé le PDF (PROCESSING_FAILED)."; }
  sleep 5
done
[ "$STATUT" = "AVAILABLE" ] || avant "document toujours « ${STATUT:-inconnu} » après 2 minutes."
echo "Document traité : AVAILABLE"

# 4. Créer le post « document ». À partir d'ici, un échec n'autorise plus le repli.
jq -n --arg author "$MEMBER_URN" --arg msg "$MESSAGE" --arg titre "$TITRE" --arg doc "$DOC_URN" --arg etat "$ETAT" \
  '{author:$author, commentary:$msg, visibility:"PUBLIC",
    distribution:{feedDistribution:"MAIN_FEED", targetEntities:[], thirdPartyDistributionChannels:[]},
    content:{media:{title:$titre, id:$doc}}, lifecycleState:$etat, isReshareDisabledByAuthor:false}' > "$TMP/post.json"
CODE=$(li -o "$TMP/post-rep.txt" -D "$TMP/post-entetes.txt" -w "%{http_code}" -X POST "https://api.linkedin.com/rest/posts" \
  -H "Content-Type: application/json" --data-binary @"$TMP/post.json")
POST_URN=$(grep -i '^x-restli-id:' "$TMP/post-entetes.txt" | tr -d '\r' | awk '{print $2}')
if [ "$CODE" != "201" ]; then
  cat "$TMP/post-rep.txt"; echo
  echo "::error title=Carrousel PDF::création du post — HTTP $CODE. État incertain : vérifier le profil avant tout nouvel envoi (pas de repli automatique)."
  exit 1
fi
echo "::notice title=Carrousel PDF::post $ETAT créé ($POST_URN)."
[ -n "${GITHUB_OUTPUT:-}" ] && echo "post_urn=$POST_URN" >> "$GITHUB_OUTPUT"

# 5. Essai : supprimer le brouillon pour ne rien laisser sur le profil.
if [ "$SUPPRIMER" = "--supprimer-apres" ]; then
  [ "$ETAT" = "DRAFT" ] || { echo "::error::--supprimer-apres refusé hors DRAFT."; exit 1; }
  ENC=$(jq -rn --arg u "$POST_URN" '$u|@uri')
  CODE=$(li -o /dev/null -w "%{http_code}" -X DELETE "https://api.linkedin.com/rest/posts/$ENC" -H "X-RestLi-Method: DELETE")
  if [ "$CODE" = "204" ] || [ "$CODE" = "200" ]; then
    echo "::notice title=Carrousel PDF::brouillon d'essai supprimé (HTTP $CODE)."
  else
    echo "::warning title=Carrousel PDF::suppression du brouillon d'essai — HTTP $CODE (il reste en brouillon, invisible du public)."
  fi
fi
exit 0
