#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Registre des points d'amelioration des publications PerfEco.

Demande de Jean-Michel du 18/11/2026 : verifier ce qui a ete REELLEMENT publie
(LinkedIn perso, LinkedIn Company, Facebook), relever ce qui peut etre ameliore
(presentation, graphisme, langue, adaptation au canal) et ENREGISTRER chaque
point pour que les publications suivantes en tiennent compte.

Le registre est automation-agent/ameliorations-publications.json.
- La routine perfeco-revue-qualite-hebdo AJOUTE les constats (-Ajouter).
- Les routines de creation LISENT les points ouverts avant de produire (lister)
  et declarent ceux qu'elles ont appliques (appliquer).
- La revue suivante VERIFIE que le point applique a bien disparu de la
  publication reelle ; sinon elle le rouvre (rouvrir) — un point n'est clos que
  constate corrige sur la page publiee, jamais sur declaration.

Usage (toujours avec python -X utf8) :
  python -X utf8 ameliorations.py lister [--format mardi|jeudi|vendredi] [--tous]
  python -X utf8 ameliorations.py ajouter --publication 2026-11-19-jeudi \
        --canal linkedin_company --categorie visuel --priorite haute \
        --constat "..." --recommandation "..." [--formats jeudi,vendredi]
  python -X utf8 ameliorations.py appliquer --id A-2026-11-22-01 --publication 2026-11-26-jeudi --comment "..."
  python -X utf8 ameliorations.py verifier --id A-... --preuve "constate corrige sur ..."
  python -X utf8 ameliorations.py rouvrir  --id A-... --raison "..."
  python -X utf8 ameliorations.py abandonner --id A-... --raison "..."
  python -X utf8 ameliorations.py recurrents      # constats revenus >= 2 fois -> candidats regle permanente
"""
import argparse
import datetime as dt
import json
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
FICHIER = os.path.join(ICI, "ameliorations-publications.json")
NC = dt.timezone(dt.timedelta(hours=11))

CATEGORIES = ["visuel", "typographie", "langue", "accroche", "structure",
              "adaptation_canal", "technique", "coherence_serie", "autre"]
CANAUX = ["linkedin_perso", "linkedin_company", "facebook", "tous"]
PRIORITES = ["haute", "moyenne", "basse"]
FORMATS = ["mardi", "jeudi", "vendredi", "tous"]


def maintenant():
    return dt.datetime.now(NC).isoformat(timespec="seconds")


def charger():
    if not os.path.exists(FICHIER):
        return {"_comment": [], "points": []}
    with open(FICHIER, encoding="utf-8") as f:
        return json.load(f)


def sauver(d):
    tmp = FICHIER + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, FICHIER)


def trouver(d, pid):
    for p in d["points"]:
        if p["id"] == pid:
            return p
    sys.exit(f"ERREUR : point {pid} introuvable")


def nouvel_id(d):
    jour = dt.datetime.now(NC).strftime("%Y-%m-%d")
    n = sum(1 for p in d["points"] if p["id"].startswith(f"A-{jour}-")) + 1
    return f"A-{jour}-{n:02d}"


def historiser(p, evenement, detail):
    p.setdefault("historique", []).append({"le": maintenant(), "evenement": evenement, "detail": detail})


def cmd_lister(a, d):
    ouverts = [p for p in d["points"]
               if a.tous or p["statut"] in ("ouvert", "rouvert", "applique")]
    if a.format:
        ouverts = [p for p in ouverts if a.format in p.get("formats", ["tous"]) or "tous" in p.get("formats", ["tous"])]
    ordre = {"haute": 0, "moyenne": 1, "basse": 2}
    ouverts.sort(key=lambda p: (ordre.get(p["priorite"], 9), p["id"]))
    if not ouverts:
        print("AUCUN point d'amelioration ouvert" + (f" pour le format {a.format}" if a.format else "") + ".")
        return
    print(f"{len(ouverts)} point(s) a prendre en compte :\n")
    for p in ouverts:
        etat = p["statut"].upper()
        print(f"[{p['id']}] {etat} · priorite {p['priorite']} · {p['categorie']} · canal {p['canal']} · formats {','.join(p.get('formats', ['tous']))}")
        print(f"   Constat        : {p['constat']}")
        print(f"   A faire        : {p['recommandation']}")
        if p["statut"] == "applique":
            print(f"   Applique dans  : {p.get('applique_dans')} (a confirmer par la prochaine revue)")
        print()


def cmd_ajouter(a, d):
    for val, liste, nom in ((a.categorie, CATEGORIES, "categorie"), (a.canal, CANAUX, "canal"),
                            (a.priorite, PRIORITES, "priorite")):
        if val not in liste:
            sys.exit(f"ERREUR : {nom} '{val}' invalide ({', '.join(liste)})")
    formats = [x.strip() for x in (a.formats or "tous").split(",") if x.strip()]
    for f_ in formats:
        if f_ not in FORMATS:
            sys.exit(f"ERREUR : format '{f_}' invalide ({', '.join(FORMATS)})")
    p = {
        "id": nouvel_id(d),
        "constate_le": maintenant(),
        "par": a.routine,
        "publication": a.publication,
        "canal": a.canal,
        "categorie": a.categorie,
        "priorite": a.priorite,
        "formats": formats,
        "constat": a.constat,
        "recommandation": a.recommandation,
        "preuve": a.preuve,
        "statut": "ouvert",
        "applique_dans": None,
        "occurrences": 1,
    }
    # Meme constat deja ouvert ? on incremente plutot que de dupliquer.
    for q in d["points"]:
        if q["statut"] in ("ouvert", "rouvert", "applique") and q["categorie"] == p["categorie"] \
                and q["recommandation"].strip().lower() == p["recommandation"].strip().lower():
            q["occurrences"] = q.get("occurrences", 1) + 1
            historiser(q, "reconstate", f"{a.publication} / {a.canal} : {a.constat}")
            sauver(d)
            print(f"DEJA CONNU : {q['id']} (occurrence {q['occurrences']})")
            return
    historiser(p, "ouvert", a.constat)
    d["points"].append(p)
    sauver(d)
    print(f"AJOUTE : {p['id']}")


def cmd_transition(a, d, statut, champ=None):
    p = trouver(d, a.id)
    p["statut"] = statut
    if champ == "applique":
        p["applique_dans"] = a.publication
        historiser(p, "applique", f"{a.publication} : {a.comment or ''}")
    elif champ == "verifie":
        p["clos_le"] = maintenant()
        historiser(p, "verifie_corrige", a.preuve)
    else:
        historiser(p, statut, a.raison)
    sauver(d)
    print(f"{a.id} -> {statut}")


def cmd_recurrents(a, d):
    rec = [p for p in d["points"] if p.get("occurrences", 1) >= 2 and p["statut"] != "abandonne"]
    if not rec:
        print("Aucun constat recurrent.")
        return
    for p in rec:
        print(f"[{p['id']}] x{p['occurrences']} · {p['categorie']} · {p['recommandation']}")
    print("\n=> Candidats a une regle PERMANENTE (charte / typographie / relecture) : a proposer a Jean-Michel.")


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    l = sp.add_parser("lister"); l.add_argument("--format"); l.add_argument("--tous", action="store_true")
    j = sp.add_parser("ajouter")
    for k in ("publication", "canal", "categorie", "priorite", "constat", "recommandation"):
        j.add_argument("--" + k, required=True)
    j.add_argument("--formats"); j.add_argument("--preuve"); j.add_argument("--routine", default="perfeco-revue-qualite-hebdo")
    ap_ = sp.add_parser("appliquer"); ap_.add_argument("--id", required=True); ap_.add_argument("--publication", required=True); ap_.add_argument("--comment")
    v = sp.add_parser("verifier"); v.add_argument("--id", required=True); v.add_argument("--preuve", required=True)
    for nom in ("rouvrir", "abandonner"):
        x = sp.add_parser(nom); x.add_argument("--id", required=True); x.add_argument("--raison", required=True)
    sp.add_parser("recurrents")
    a = ap.parse_args()
    d = charger()
    if a.cmd == "lister": cmd_lister(a, d)
    elif a.cmd == "ajouter": cmd_ajouter(a, d)
    elif a.cmd == "appliquer": cmd_transition(a, d, "applique", "applique")
    elif a.cmd == "verifier": cmd_transition(a, d, "clos", "verifie")
    elif a.cmd == "rouvrir": cmd_transition(a, d, "rouvert")
    elif a.cmd == "abandonner": cmd_transition(a, d, "abandonne")
    elif a.cmd == "recurrents": cmd_recurrents(a, d)


if __name__ == "__main__":
    main()
