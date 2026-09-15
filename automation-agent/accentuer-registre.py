# -*- coding: utf-8 -*-
"""
Accentue les champs AFFICHES du registre publications.json : `sujet` et `libelle`.

Cree le 16/09/2026 sur demande de Jean-Michel : le calendrier Word depose sur OneDrive
affichait « Du cap aux resultats », « a definir », « Traiter la cause des problemes
recurrents » — lisible mais negligé pour un document diffusable.

PORTEE VOLONTAIREMENT LIMITEE :
  - `sujet` et `libelle` UNIQUEMENT (ce sont les seuls champs rendus dans le calendrier) ;
  - les `note` (40 000 caracteres, 105 entrees) sont laissees telles quelles : elles sont
    internes, jamais affichees, et les accentuer au jugé introduirait plus de risque que de
    valeur.

SANS DANGER POUR LES SCRIPTS : tous les lecteurs du registre sont deja en UTF-8 explicite —
PowerShell via [System.IO.File]::ReadAllText(path, UTF8Encoding($false)), Python via
io.open(..., encoding='utf-8'). Verifie le 16/09/2026 sur planning.ps1, etendre-cahier.ps1,
validations.ps1, calendrier-lisible.py et clore-publication.py.

    python accentuer-registre.py            # simulation, n'ecrit rien
    python accentuer-registre.py --ecrire   # applique
"""
import io, json, os, re, sys, collections

ICI = os.path.dirname(os.path.abspath(__file__))
REGISTRE = os.path.join(ICI, 'publications.json')

# (motif, remplacement) — appliques dans l'ordre. Les bornes \b evitent de toucher
# l'interieur d'un mot deja correct.
REGLES = [
    # --- elisions : « l organisation » -> « l'organisation » ---
    (r"\bl (organisation|argent|IA|habitat|An|episode|épisode|aveugle|energie|énergie|information)\b", r"l'\1"),
    (r"\bc (est)\b", r"c'\1"),
    (r"\bd (abord|avant)\b", r"d'\1"),
    (r"\bqu (un|une|est-ce)\b", r"qu'\1"),
    (r"\bs (est)\b", r"s'\1"),
    (r"\bn (est)\b", r"n'\1"),

    # --- vocabulaire recurrent ---
    (r"\bdediee\b", u"dédiée"),
    (r"\bDediee\b", u"Dédiée"),
    (r"\bresultats\b", u"résultats"),
    (r"\bresultat\b", u"résultat"),
    (r"\bSerie\b", u"Série"),
    (r"\bserie\b", u"série"),
    (r"\bhors-serie\b", u"hors-série"),
    (r"\bepisode\b", u"épisode"),
    (r"\bferie\b", u"férié"),
    (r"\bFERIE\b", u"FÉRIÉ"),
    (r"\bFerie\b", u"Férié"),
    (r"\bNoel\b", u"Noël"),
    (r"\beconomique\b", u"économique"),
    (r"\bpublie\b", u"publié"),
    (r"\bequipes\b", u"équipes"),
    (r"\balignees\b", u"alignées"),
    (r"\bmemes\b", u"mêmes"),
    (r"\bpriorites\b", u"priorités"),
    (r"\bEtre\b", u"Être"),
    (r"\bpret\b", u"prêt"),
    (r"\bsiege\b", u"siège"),
    (r"\bFete\b", u"Fête"),
    (r"\bCitoyennete\b", u"Citoyenneté"),
    (r"\bdecision\b", u"décision"),
    (r"\bdecisions\b", u"décisions"),
    (r"\breellement\b", u"réellement"),
    (r"\bdecider\b", u"décider"),
    (r"\bproblemes\b", u"problèmes"),
    (r"\brecurrents\b", u"récurrents"),
    (r"\bNumeriser\b", u"Numériser"),
    (r"\bcomplexite\b", u"complexité"),
    (r"\bamelioration\b", u"amélioration"),
    (r"\bdeformer\b", u"déformer"),
    (r"\bsynthese\b", u"synthèse"),
    (r"\bcouts\b", u"coûts"),
    (r"\bverifie\b", u"vérifie"),
    (r"\bCredits\b", u"Crédits"),
    (r"\btresorerie\b", u"trésorerie"),
    (r"\bsalaries\b", u"salariés"),
    (r"\bmodele\b", u"modèle"),
    (r"\boperationnel\b", u"opérationnel"),
    (r"\bregle\b", u"règle"),
    (r"\bcomite\b", u"comité"),
    (r"\becrire\b", u"écrire"),
    (r"\bavancement abandonne\b", u"avancement abandonné"),
    (r"\boeuvre\b", u"œuvre"),
    (r"\bdeja\b", u"déjà"),
    (r"\bDERNIERE\b", u"DERNIÈRE"),
    (r"\bANNULE\b", u"ANNULÉ"),
    (r"\bBASCULEE\b", u"BASCULÉE"),
    (r"\bcreees\b", u"créées"),
    (r"\bactivites\b", u"activités"),
    (r"\bcreances\b", u"créances"),
    (r"\bdependances\b", u"dépendances"),
    (r"\bFiliere\b", u"Filière"),
    (r"\bplutot\b", u"plutôt"),
    (r"\bretention\b", u"rétention"),
    (r"\bemplois salaries\b", u"emplois salariés"),
    (r"\bvisibilite\b", u"visibilité"),
    (r"\babandonne\b", u"abandonné"),
    (r"\benergie\b", u"énergie"),
    (r"\becart\b", u"écart"),
    (r"\bmanufactures\b", u"manufacturés"),
    (r"\bprive\b", u"privé"),
    (r"\beco\b", u"éco"),

    # --- « a » preposition -> « à » (cas surs seulement, jamais le verbe avoir) ---
    (r"\ba definir\b", u"à définir"),
    (r"\bles 3 a 5\b", u"les 3 à 5"),
    (r"\ba produire\b", u"à produire"),
    (r"\ba voix haute\b", u"à voix haute"),
    (r"\bDu cap a la\b", u"Du cap à la"),
    (r"\bInflation a \+", u"Inflation à +"),
    (r"\ba décider\b", u"à décider"),
    (r"\bterminee\b", u"terminée"),
    (r"\baide a\b", u"aide à"),
    (r"\bcollaborateurs a produire\b", u"collaborateurs à produire"),
    (r"\bface a\b", u"face à"),
    (r"\bgains rapides a une\b", u"gains rapides à une"),
    (r"\bCampagne dédiée (\d+)/10\b", r"Campagne dédiée \1/10"),
]


def accentue(t):
    for motif, repl in REGLES:
        t = re.sub(motif, repl, t)
    return t


def main():
    ecrire = '--ecrire' in sys.argv
    texte = io.open(REGISTRE, encoding='utf-8', newline='').read()
    data = json.loads(texte, object_pairs_hook=collections.OrderedDict)

    modifs = []
    for pub in data['publications']:
        for champ in ('sujet', 'libelle'):
            av = pub.get(champ)
            if not av:
                continue
            ap = accentue(av)
            if ap != av:
                modifs.append((pub.get('date_nc', '?'), champ, av, ap))
                if ecrire:
                    pub[champ] = ap

    vus = set()
    for date, champ, av, ap in modifs:
        if av in vus:
            continue
        vus.add(av)
        print(u'  %-10s %-8s %s' % (date, champ, av))
        print(u'  %-10s %-8s -> %s' % ('', '', ap))
    print(u'')
    print(u'%d champ(s) modifie(s), %d texte(s) distinct(s)' % (len(modifs), len(vus)))

    if ecrire:
        io.open(REGISTRE, 'w', encoding='utf-8', newline='').write(
            json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        print(u'REGISTRE ECRIT')
    else:
        print(u'SIMULATION — rien ecrit. Relancer avec --ecrire pour appliquer.')


if __name__ == '__main__':
    main()
