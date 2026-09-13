#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Clôture une échéance du registre des publications : statut -> "publie", avec sa preuve.

    python3 automation-agent/clore-publication.py <date_nc> <format> "<preuve>"
    python3 automation-agent/clore-publication.py 2026-09-17 jeudi "Make 4 operations ..."

POURQUOI CE SCRIPT EXISTE (13/09/2026)
--------------------------------------
Jusqu'ici, AUCUNE routine ne clôturait le registre après une publication. Le statut
"publie" ne s'écrivait qu'à la main. Conséquence mécanique : toute publication réussie
finissait quelques jours plus tard en fausse « échéance dépassée », et
check-preparation-contenu échouait pour une publication pourtant partie normalement.

C'est arrivé le 11/09/2026 sur le post court du jeudi 10/09 : le garde-fou signalait
« soit elle n'est jamais partie, soit personne n'a clos son suivi » alors que Make
affichait statut=1 et 4 opérations, et que le post Facebook était en ligne. Une fausse
alerte de ce genre coûte plus cher qu'elle n'en a l'air : c'est ainsi qu'on finit par
ignorer le seul filet indépendant de Cowork.

La clôture est donc faite par check-apres-publication.yml, qui détient la preuve
(exécution Make + post Facebook vérifié) au moment exact où elle est fiable.

POURQUOI UNE ÉDITION CIBLÉE ET NON UNE RÉÉCRITURE JSON
------------------------------------------------------
publications.json est écrit par planning.ps1, donc au format de ConvertTo-Json de
PowerShell : indentation à 4 espaces alignée, non-ASCII échappé en \\uXXXX. Réécrire le
fichier avec un autre outil (jq, json.dump) le reformaterait INTÉGRALEMENT à chaque
publication, et planning.ps1 le reformaterait en sens inverse au passage suivant : deux
diffs de 3 000 lignes par semaine, dans lesquels plus personne ne verrait un vrai
changement. On modifie donc uniquement les deux valeurs concernées, dans le bloc de
l'échéance visée, et on relit le résultat en JSON avant d'écrire.

Le script est IDEMPOTENT : une échéance déjà "publie*" (ou "annule") est laissée telle
quelle et le script sort en 0. Il peut donc être rejoué sans risque.
"""

import io
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRE = os.path.join(RACINE, "automation-agent", "publications.json")


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip().split("\n\n")[1])
        return 2

    date_nc, fmt, preuve = sys.argv[1], sys.argv[2], sys.argv[3]

    if not re.match(r"^\d{4}-\d{2}-\d{2}$", date_nc):
        print("ERREUR : date attendue au format AAAA-MM-JJ, recu '%s'." % date_nc)
        return 2

    # newline="" des DEUX côtés : sans lui, la lecture convertit les CRLF de PowerShell
    # en LF et l'écriture les fige ainsi — le fichier entier changerait de fins de ligne
    # à chaque clôture. Invisible dans git (core.autocrlf=true côté Windows, LF côté
    # runner Linux), mais un diff de 2 705 lignes pour un changement de 2 valeurs sur
    # tout poste configuré autrement.
    texte = io.open(REGISTRE, encoding="utf-8", newline="").read()
    registre = json.loads(texte)

    # On identifie l'échéance sur le couple (date, format) : il est unique dans le
    # registre, alors que l'id ne suit la convention <date>-<format> que pour les
    # formats mardi/jeudi/vendredi (les entrées ad-hoc et samedi y échappent).
    cibles = [e for e in registre["publications"]
              if e.get("date_nc") == date_nc and e.get("format") == fmt]

    if not cibles:
        print("Aucune echeance %s du %s dans le registre : rien a clore." % (fmt, date_nc))
        return 0
    if len(cibles) > 1:
        print("ERREUR : %d echeances %s du %s — ambigu, abandon." % (len(cibles), fmt, date_nc))
        return 1

    cible = cibles[0]
    statut = cible.get("statut", "")

    if statut.startswith("publie") or statut == "annule":
        print("Echeance %s du %s deja en '%s' : rien a faire." % (fmt, date_nc, statut))
        return 0

    # Bornage textuel du bloc de cette échéance : de son "id" jusqu'à l'"id" suivant.
    ancre = '"id": "%s"' % cible["id"]
    debut = texte.find(ancre)
    if debut < 0:
        # L'id peut être écrit avec un espacement différent ; on retombe sur la date.
        m = re.search(r'"id":\s*"%s"' % re.escape(cible["id"]), texte)
        if not m:
            print("ERREUR : bloc de l'echeance introuvable dans le texte du registre.")
            return 1
        debut = m.start()

    suivant = re.search(r'"id":\s*"', texte[debut + len(ancre):])
    fin = debut + len(ancre) + suivant.start() if suivant else len(texte)
    bloc = texte[debut:fin]

    def remplacer(bloc, champ, valeur_json, motif_valeur):
        motif = r'("%s":\s*)(%s)' % (champ, motif_valeur)
        nouveau, n = re.subn(motif, lambda m: m.group(1) + valeur_json, bloc, count=1)
        if n != 1:
            raise RuntimeError("champ '%s' introuvable (ou multiple) dans le bloc" % champ)
        return nouveau

    # json.dumps produit exactement l'échappement attendu, y compris \\uXXXX pour les
    # accents : on reste homogène avec ce qu'écrit ConvertTo-Json.
    try:
        bloc = remplacer(bloc, "statut", json.dumps("publie", ensure_ascii=True), r'"[^"]*"')
        bloc = remplacer(bloc, "preuve", json.dumps(preuve, ensure_ascii=True),
                         r'null|"(?:[^"\\]|\\.)*"')
    except RuntimeError as err:
        print("ERREUR : %s." % err)
        return 1

    texte = texte[:debut] + bloc + texte[fin:]
    texte = re.sub(r'("derniere_maj":\s*)"[^"]*"',
                   lambda m: m.group(1) + json.dumps(date_nc), texte, count=1)

    # Filet : on ne remplace le fichier que si le résultat est du JSON valide ET que
    # l'échéance visée est bien la seule à avoir bougé.
    try:
        apres = json.loads(texte)
    except ValueError as err:
        print("ERREUR : le resultat n'est pas du JSON valide (%s) — rien n'a ete ecrit." % err)
        return 1

    avant_pubs = registre["publications"]
    apres_pubs = apres["publications"]
    if len(avant_pubs) != len(apres_pubs):
        print("ERREUR : le nombre d'echeances a change — rien n'a ete ecrit.")
        return 1
    bouges = [a["id"] for a, b in zip(avant_pubs, apres_pubs) if a != b]
    if bouges != [cible["id"]]:
        print("ERREUR : echeances modifiees inattendues %s — rien n'a ete ecrit." % bouges)
        return 1

    io.open(REGISTRE, "w", encoding="utf-8", newline="").write(texte)
    print("Echeance %s du %s clôturée : '%s' -> 'publie'." % (fmt, date_nc, statut))
    print("  preuve : %s" % preuve)
    return 0


if __name__ == "__main__":
    sys.exit(main())
