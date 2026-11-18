#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PLANIFIE L'ARTICLE DE FOND DU JEUDI SUR perfsystemique.fr PAR L'API REST
# (19/11/2026 — demande de Jean-Michel : « tu peux intégrer perfsystemique.fr dans
# la chaîne de diffusion média avec de la création d'articles », choix « Jeudi :
# article Performance » et « Dans le cloud »).
#
# Usage : scripts/wordpress-article.sh <file.json> <planifier|essai>
#   planifier : crée l'article en BROUILLON avec les metas Jetpack, le relit, puis le
#               passe en « future » à date_prevue 11h03 (heure du site = Pacific/Noumea).
#               IDEMPOTENT : si un article du même slug existe déjà, il est seulement vérifié.
#   essai     : même création en brouillon (slug suffixé -essai-<run>), relecture
#               complète, puis SUPPRESSION DÉFINITIVE (force=true). Rien n'est publié.
#
# Lit le bloc .wordpress de la file :
#   titre, slug, extrait, contenu_html, categorie_id (10 Pilotage | 11 Organisation), tags[] (noms)
# env WP_LOGIN, WP_APP_PASSWORD
#
# PIÈGES CONNUS (mémoire) :
#   - un JSON mal encodé crée un article VIDE en HTTP 201 → on RELIT toujours le contenu stocké ;
#   - l'auto-partage Jetpack (LinkedIn + Facebook) doublerait les posts du jour → deux metas
#     posées AVANT le passage en « future » (valeurs de l'article #119, parti sans partage) ;
#   - une date passée en « future » = publication IMMÉDIATE → refus après 10h45 le jour même ;
#   - un slug déjà pris reçoit « -2 » → slug relu et comparé.
# Sortie 0 : planifié (ou déjà planifié et conforme) / essai réussi / rien à faire.  1 : échec.
# ---------------------------------------------------------------------------
set -uo pipefail
FILE="${1:?fichier de file manquant}"
MODE="${2:?planifier ou essai}"
SITE="https://perfsystemique.fr/wp-json/wp/v2"
TMP="$(mktemp -d)"
err() { echo "::error title=Article WordPress::$1"; exit 1; }
[ -n "${WP_LOGIN:-}" ] && [ -n "${WP_APP_PASSWORD:-}" ] || err "WP_LOGIN ou WP_APP_PASSWORD vide."
AUTH="Authorization: Basic $(printf '%s:%s' "$WP_LOGIN" "$WP_APP_PASSWORD" | base64 -w0)"
wp() { curl -s -H "$AUTH" "$@"; }

if [ "$(jq -r 'has("wordpress")' "$FILE")" != "true" ]; then
  echo "Pas de bloc « wordpress » dans $FILE : aucun article à planifier."
  exit 0
fi
W() { jq -r ".wordpress.$1 // empty" "$FILE"; }
TITRE=$(W titre); SLUG=$(W slug); EXTRAIT=$(W extrait); CAT=$(W categorie_id)
DATE_PREVUE=$(jq -r '.date_prevue // empty' "$FILE")
jq -r '.wordpress.contenu_html // empty' "$FILE" > "$TMP/contenu.html"

# 1. Contrôles de fond, AVANT tout appel d'écriture.
[ -n "$TITRE" ] || err "wordpress.titre vide."
echo "$SLUG" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || err "wordpress.slug « $SLUG » invalide (minuscules, chiffres, tirets, sans accent)."
[ -n "$EXTRAIT" ] || err "wordpress.extrait vide."
case "$CAT" in 10|11) ;; *) err "wordpress.categorie_id « $CAT » : attendu 10 (Pilotage) ou 11 (Organisation)." ;; esac
MOTS=$(sed 's/<[^>]*>/ /g' "$TMP/contenu.html" | wc -w)
[ "$MOTS" -ge 700 ] || err "article de $MOTS mots (attendu 800 à 1 200)."
[ "$MOTS" -le 1500 ] || err "article de $MOTS mots (attendu 800 à 1 200)."
echo "Article : « $TITRE » — $MOTS mots — slug $SLUG — catégorie $CAT — date prévue $DATE_PREVUE 11h03"

if [ "$MODE" = "planifier" ]; then
  AUJ=$(TZ="Pacific/Noumea" date +%Y-%m-%d); HEURE=$(TZ="Pacific/Noumea" date +%H%M)
  [ -n "$DATE_PREVUE" ] || err "date_prevue absente."
  if [[ "$DATE_PREVUE" < "$AUJ" ]]; then echo "date_prevue $DATE_PREVUE passée : rien à planifier."; exit 0; fi
  if [ "$DATE_PREVUE" = "$AUJ" ] && [ "$HEURE" -ge 1045 ]; then
    err "il est $HEURE NC le jour même : planifier maintenant publierait hors de l'heure prévue (WordPress publie aussitôt une date passée). À traiter à la main."
  fi
  MAX=$(TZ="Pacific/Noumea" date -d "+10 days" +%Y-%m-%d)
  if [[ "$DATE_PREVUE" > "$MAX" ]]; then echo "date_prevue $DATE_PREVUE à plus de 10 jours : planification remise à plus tard."; exit 0; fi
  # Idempotence : un article de ce slug existe-t-il déjà (tous statuts) ?
  wp -o "$TMP/exist.json" "$SITE/posts?slug=$SLUG&status=publish,future,draft,pending,private&context=edit"
  EXIST=$(jq -r '.[0].id // empty' "$TMP/exist.json")
  if [ -n "$EXIST" ]; then
    echo "Article #$EXIST déjà présent (statut $(jq -r '.[0].status' "$TMP/exist.json")) : vérification seule."
    POST_ID="$EXIST"; DEJA=1
  fi
  SLUG_CREE="$SLUG"; ETAT_FINAL="future"
else
  SLUG_CREE="$SLUG-essai-${GITHUB_RUN_ID:-local}"; ETAT_FINAL="draft"
  DATE_PREVUE=$(TZ="Pacific/Noumea" date -d "+7 days" +%Y-%m-%d)
fi
DATE_WP="${DATE_PREVUE}T11:03:00"

# 2. Étiquettes : noms → identifiants (création si absente).
TAGS="[]"
while IFS= read -r NOM; do
  [ -n "$NOM" ] || continue
  wp -o "$TMP/t.json" -G "$SITE/tags" --data-urlencode "search=$NOM" --data-urlencode "per_page=100"
  ID=$(jq -r --arg n "$NOM" '[.[] | select((.name|ascii_downcase) == ($n|ascii_downcase))][0].id // empty' "$TMP/t.json")
  if [ -z "$ID" ]; then
    if [ "$MODE" = "essai" ]; then echo "Étiquette « $NOM » absente : serait créée (pas en essai)."; continue; fi
    jq -n --arg n "$NOM" '{name:$n}' > "$TMP/tn.json"
    wp -o "$TMP/tc.json" -X POST "$SITE/tags" -H "Content-Type: application/json; charset=utf-8" --data-binary @"$TMP/tn.json"
    ID=$(jq -r '.id // .data.term_id // empty' "$TMP/tc.json")
  fi
  [ -n "$ID" ] && TAGS=$(jq -c --argjson i "$ID" '. + [$i]' <<< "$TAGS")
done < <(jq -r '.wordpress.tags[]? // empty' "$FILE")
echo "Étiquettes : $TAGS"

# 3. Création en BROUILLON, metas Jetpack posées d'emblée. JSON construit par jq (UTF-8 sûr).
if [ -z "${DEJA:-}" ]; then
  jq -n --arg t "$TITRE" --arg s "$SLUG_CREE" --arg e "$EXTRAIT" --rawfile c "$TMP/contenu.html" \
        --arg d "$DATE_WP" --argjson cat "$CAT" --argjson tags "$TAGS" \
    '{title:$t, slug:$s, excerpt:$e, content:$c, status:"draft", date:$d, categories:[$cat], tags:$tags,
      meta:{jetpack_publicize_feature_enabled:false, jetpack_social_post_already_shared:true}}' > "$TMP/corps.json"
  CODE=$(wp -o "$TMP/cree.json" -w "%{http_code}" -X POST "$SITE/posts" -H "Content-Type: application/json; charset=utf-8" --data-binary @"$TMP/corps.json")
  POST_ID=$(jq -r '.id // empty' "$TMP/cree.json")
  [ "$CODE" = "201" ] && [ -n "$POST_ID" ] || err "création du brouillon — HTTP $CODE $(jq -c '{code,message}' "$TMP/cree.json" 2>/dev/null)."
  echo "Brouillon #$POST_ID créé."
fi

# 4. RELECTURE de ce que WordPress a réellement stocké (piège de l'article vide en 201).
verifier() {
  wp -o "$TMP/lu.json" "$SITE/posts/$POST_ID?context=edit"
  local KO=0
  local L=$(jq -r '.content.raw | length' "$TMP/lu.json")
  local S=$(jq -r '.slug' "$TMP/lu.json")
  local D=$(jq -r '.date' "$TMP/lu.json")
  local C=$(jq -c '.categories' "$TMP/lu.json")
  local X=$(jq -r '.excerpt.raw' "$TMP/lu.json")
  local M1=$(jq -r '.meta.jetpack_publicize_feature_enabled' "$TMP/lu.json")
  local M2=$(jq -r '.meta.jetpack_social_post_already_shared' "$TMP/lu.json")
  echo "Relu #$POST_ID : statut $(jq -r .status "$TMP/lu.json"), contenu $L car., slug $S, date $D, catégories $C, metas Jetpack $M1/$M2"
  [ "$L" -ge 3000 ] || { echo "::error title=Article WordPress::contenu stocké de $L caractères — article VIDE ou tronqué."; KO=1; }
  [ "$S" = "$SLUG_CREE" ] || { echo "::error title=Article WordPress::slug stocké « $S » ≠ « $SLUG_CREE » (slug déjà pris ? les liens des posts seraient faux)."; KO=1; }
  [ "$D" = "$DATE_WP" ] || { echo "::error title=Article WordPress::date stockée $D ≠ $DATE_WP."; KO=1; }
  [ "$C" = "[$CAT]" ] || { echo "::error title=Article WordPress::catégories $C ≠ [$CAT]."; KO=1; }
  [ "$X" = "$EXTRAIT" ] || { echo "::error title=Article WordPress::extrait altéré (accents ?) : « $(echo "$X" | head -c 120) »."; KO=1; }
  [ "$M1" = "false" ] && [ "$M2" = "true" ] || { echo "::error title=Article WordPress::metas Jetpack $M1/$M2 (attendu false/true) — l'article serait auto-partagé sur LinkedIn et Facebook."; KO=1; }
  return $KO
}
if ! verifier; then
  [ -z "${DEJA:-}" ] && [ "$MODE" = "essai" ] && wp -o /dev/null -X DELETE "$SITE/posts/$POST_ID?force=true"
  err "article #$POST_ID non conforme — laissé en brouillon, rien n'est planifié."
fi

# 5. Fin : essai → suppression définitive ; planifier → passage en « future ».
if [ "$MODE" = "essai" ]; then
  CODE=$(wp -o "$TMP/del.json" -w "%{http_code}" -X DELETE "$SITE/posts/$POST_ID?force=true")
  [ "$CODE" = "200" ] && echo "::notice title=Article WordPress (essai)::brouillon #$POST_ID créé, relu conforme ($MOTS mots, metas Jetpack correctes, accents intacts), puis supprimé définitivement." \
    || err "essai réussi mais suppression du brouillon #$POST_ID — HTTP $CODE (à supprimer à la main)."
  exit 0
fi
STATUT=$(jq -r '.status' "$TMP/lu.json")
if [ "$STATUT" = "draft" ]; then
  jq -n '{status:"future"}' > "$TMP/fut.json"
  CODE=$(wp -o "$TMP/fut-rep.json" -w "%{http_code}" -X POST "$SITE/posts/$POST_ID" -H "Content-Type: application/json" --data-binary @"$TMP/fut.json")
  [ "$CODE" = "200" ] || err "passage en « future » de #$POST_ID — HTTP $CODE."
  verifier || err "#$POST_ID non conforme après le passage en « future »."
  STATUT=$(jq -r '.status' "$TMP/lu.json")
fi
case "$STATUT" in
  future)  echo "::notice title=Article WordPress::#$POST_ID PLANIFIÉ le $DATE_PREVUE à 11h03 NC — $(jq -r .link "$TMP/lu.json")" ;;
  publish) echo "::notice title=Article WordPress::#$POST_ID déjà publié — $(jq -r .link "$TMP/lu.json")" ;;
  *)       err "#$POST_ID au statut « $STATUT » (attendu future)." ;;
esac
[ -n "${GITHUB_OUTPUT:-}" ] && { echo "wp_post_id=$POST_ID"; echo "wp_statut=$STATUT"; } >> "$GITHUB_OUTPUT"
exit 0
