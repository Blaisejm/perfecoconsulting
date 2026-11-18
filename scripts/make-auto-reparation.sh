#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AUTO-RÉPARATION DU SCÉNARIO MAKE 6916780 (diffusion 100 % cloud, étape 2, 19/11/2026)
#
# POURQUOI : sept épisodes depuis août où le scénario s'est retrouvé INACTIF et où
# la réactivation attendait que Jean-Michel ouvre Make. Ce script la fait seul,
# depuis check-avant-publication.yml (07h00 et 10h30 NC, avant 11h00).
#
# PRUDENCE — il NE réactive PAS si la file du webhook n'est pas vide ou illisible :
# réactiver ferait publier d'un coup des appels en attente, donc hors calendrier.
# Dans ce cas il échoue avec la marche à suivre (vider la file dans Make, puis relancer).
#
# Usage : scripts/make-auto-reparation.sh [--dry-run]
#   --dry-run : décrit ce qu'il ferait, ne modifie rien.
#   env MAKE_API_TOKEN — droits nécessaires : scenarios:read, scenarios:write,
#   hooks:read, hooks:write (sans écriture, il diagnostique seulement).
#
# Sortie 0 : scénario actif (déjà, ou réactivé et relu actif).  Sortie 1 : à réparer à la main.
# Écrit dans $GITHUB_OUTPUT : etat=actif|reactive|a_reactiver|irreparable
# ---------------------------------------------------------------------------
set -uo pipefail
DRY="${1:-}"
SCENARIO=6916780
HOOK=3534727
API="https://eu1.make.com/api/v2"
EDIT="https://eu1.make.com/1970457/scenarios/$SCENARIO/edit"
H="Authorization: Token ${MAKE_API_TOKEN:?MAKE_API_TOKEN vide}"
sortie() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "etat=$1" >> "$GITHUB_OUTPUT"; exit "$2"; }
lire() { curl -s -o "$2" -w "%{http_code}" -H "$H" "$API/$1"; }

CODE=$(lire "scenarios/$SCENARIO" /tmp/rep-sc.json)
if [ "$CODE" != "200" ]; then
  echo "::error title=Make::scénario $SCENARIO illisible — HTTP $CODE (MAKE_API_TOKEN expiré ou sans scenarios:read)."
  sortie irreparable 1
fi
ACTIF=$(jq -r '.scenario.isActive' /tmp/rep-sc.json)
INVALIDE=$(jq -r '.scenario.isinvalid' /tmp/rep-sc.json)
echo "Scénario $SCENARIO : isActive=$ACTIF isinvalid=$INVALIDE"
if [ "$ACTIF" = "true" ] && [ "$INVALIDE" != "true" ]; then
  echo "✅ Scénario actif et valide — rien à réparer."
  sortie actif 0
fi

echo "::warning title=Make::scénario $SCENARIO INACTIF (isinvalid=$INVALIDE) — tentative d'auto-réparation."
if [ "$INVALIDE" = "true" ]; then
  # Un scénario « invalid » a une erreur de configuration (module, connexion) : le
  # relancer ne la corrige pas, il faut l'ouvrir.
  echo "::error title=Make::scénario marqué INVALIDE — configuration à corriger dans Make (connexion LinkedIn/Facebook expirée ?) : $EDIT"
  sortie irreparable 1
fi

# File du webhook : la réactivation la viderait d'un coup en publiant tout.
CODE=$(lire "hooks/$HOOK/incomings" /tmp/rep-inc.json)
if [ "$CODE" != "200" ]; then
  echo "::error title=Make::file du webhook $HOOK illisible (HTTP $CODE — le jeton n'a pas hooks:read). Réactivation REFUSÉE à l'aveugle : vérifier la file dans Make, puis réactiver : $EDIT"
  sortie irreparable 1
fi
EN_FILE=$(jq -r '(.incomings // []) | length' /tmp/rep-inc.json)
if [ "$EN_FILE" != "0" ]; then
  echo "::error title=Make::$EN_FILE appel(s) en file sur le webhook $HOOK. Les réactiver les publierait HORS CALENDRIER. Les supprimer dans Make (Webhooks → PerfEco → file d'attente), puis relancer ce workflow : $EDIT"
  sortie irreparable 1
fi
echo "File du webhook vide : réactivation sans risque de publication en retard."

# Webhook désactivé ? (Make le coupe parfois en même temps que le scénario.)
CODE=$(lire "hooks/$HOOK" /tmp/rep-hk.json)
ACTIVE_HOOK=$(jq -r '.hook.enabled // empty' /tmp/rep-hk.json 2>/dev/null)
echo "Webhook $HOOK : HTTP $CODE, enabled=${ACTIVE_HOOK:-?}"

if [ "$DRY" = "--dry-run" ]; then
  [ "$ACTIVE_HOOK" = "false" ] && echo "::notice title=Make (essai)::réactiverait le webhook $HOOK (POST hooks/$HOOK/enable)."
  echo "::notice title=Make (essai)::réactiverait le scénario $SCENARIO (POST scenarios/$SCENARIO/start), puis relirait son état. Rien n'a été modifié."
  sortie a_reactiver 0
fi

if [ "$ACTIVE_HOOK" = "false" ]; then
  CODE=$(curl -s -o /tmp/rep-en.json -w "%{http_code}" -X POST -H "$H" "$API/hooks/$HOOK/enable")
  echo "Réactivation du webhook : HTTP $CODE"; cat /tmp/rep-en.json; echo
fi
CODE=$(curl -s -o /tmp/rep-start.json -w "%{http_code}" -X POST -H "$H" "$API/scenarios/$SCENARIO/start")
echo "Réactivation du scénario : HTTP $CODE"; cat /tmp/rep-start.json; echo
if [ "$CODE" != "200" ]; then
  echo "::error title=Make::réactivation refusée — HTTP $CODE (jeton sans scenarios:write ? limite de 2 scénarios actifs du plan gratuit atteinte ?) : $EDIT"
  sortie irreparable 1
fi

# Ne jamais croire la réponse : relire l'état (leçon du 17/07, « Accepted » ≠ fait).
sleep 5
lire "scenarios/$SCENARIO" /tmp/rep-sc2.json >/dev/null
if [ "$(jq -r '.scenario.isActive' /tmp/rep-sc2.json)" = "true" ]; then
  echo "::warning title=Make::scénario $SCENARIO RÉACTIVÉ automatiquement et relu actif. Chercher la cause de la désactivation (historique du scénario)."
  sortie reactive 0
fi
echo "::error title=Make::réactivation annoncée mais le scénario est relu INACTIF — à faire à la main : $EDIT"
sortie irreparable 1
