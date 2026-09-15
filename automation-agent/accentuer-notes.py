# -*- coding: utf-8 -*-
"""
Accentue les champs `note` du registre publications.json (105 entrees, ~40 000 caracteres).

Complement de accentuer-registre.py, qui traite `sujet` et `libelle`. Demande de Jean-Michel
le 16/09/2026, apres l'accentuation des champs affiches.

DEUX FAMILLES DE REGLES, et la distinction compte :

  1. MOTS NON AMBIGUS -> remplacement direct. « creneau » n'est jamais autre chose que
     « creneau » mal ecrit.

  2. PARTICIPES AMBIGUS -> accentues UNIQUEMENT derriere un auxiliaire.
     « remplace » peut etre le present (« ceci remplace la decision ») ou le participe
     (« a ete remplace »). Accentuer aveuglement introduirait des fautes dans le registre.
     Regle retenue : on n'accentue que si le mot suit etre/avoir. Au pire un participe reste
     non accentue — l'etat actuel ; jamais un present ne devient faux.

    python accentuer-notes.py            # simulation
    python accentuer-notes.py --ecrire   # applique
"""
import io, json, os, re, sys, collections

ICI = os.path.dirname(os.path.abspath(__file__))
REGISTRE = os.path.join(ICI, 'publications.json')

# ---------------------------------------------------------------------------
# 1. Mots non ambigus
# ---------------------------------------------------------------------------
MOTS = {
    # e -> é
    'creneau': u'créneau', 'creneaux': u'créneaux', 'consequence': u'conséquence',
    'consequences': u'conséquences', 'creation': u'création', 'referentiel': u'référentiel',
    'methode': u'méthode', 'detail': u'détail', 'verif': u'vérif',
    'verification': u'vérification', 'verifications': u'vérifications',
    'prevue': u'prévue', 'prevu': u'prévu', 'prevus': u'prévus', 'prevues': u'prévues',
    'inchanges': u'inchangés', 'inchangee': u'inchangée', 'inchange': u'inchangé',
    'schema': u'schéma', 'echec': u'échec', 'echecs': u'échecs', 'diversite': u'diversité',
    'decalage': u'décalage', 'decalages': u'décalages', 'generale': u'générale',
    'general': u'général', 'etape': u'étape', 'etapes': u'étapes', 'repond': u'répond',
    'entree': u'entrée', 'entrees': u'entrées', 'reparation': u'réparation',
    'echeance': u'échéance', 'echeances': u'échéances', 'ecarts': u'écarts', 'ecart': u'écart',
    'aout': u'août', 'reecrite': u'réécrite', 'reecrit': u'réécrit', 'reecriture': u'réécriture',
    'recu': u'reçu', 'confirmee': u'confirmée', 'confirmes': u'confirmés',
    'apportee': u'apportée', 'controle': u'contrôle', 'controles': u'contrôles',
    'validee': u'validée', 'consecutif': u'consécutif', 'consecutifs': u'consécutifs',
    'etre': u'être', 'etant': u'étant', 'corrigee': u'corrigée', 'levee': u'levée',
    'leves': u'levés', 'verifiees': u'vérifiées', 'verifies': u'vérifiés',
    'verifier': u'vérifier', 'verifiee': u'vérifiée', 'repondent': u'répondent',
    'declares': u'déclarés', 'depassee': u'dépassée', 'programmee': u'programmée',
    'ecrit': u'écrit', 'ecrire': u'écrire', 'constate': u'constaté', 'fraicheur': u'fraîcheur',
    'cree': u'créé', 'creer': u'créer', 'restee': u'restée', 'preparation': u'préparation',
    'deja': u'déjà', 'reportee': u'reportée', 'priorite': u'priorité', 'priorites': u'priorités',
    'etait': u'était', 'declenchee': u'déclenchée', 'sourcage': u'sourçage',
    'avancait': u'avançait', 'posee': u'posée', 'regle': u'règle', 'regles': u'règles',
    'serie': u'série', 'filiere': u'filière', 'fenetre': u'fenêtre', 'feries': u'fériés',
    'ferie': u'férié', 'versionne': u'versionné', 'passee': u'passée',
    'precisement': u'précisément', 'depot': u'dépôt', 'etaye': u'étayé', 'etayee': u'étayée',
    'defini': u'défini', 'defaillante': u'défaillante', 'telechargees': u'téléchargées',
    'seance': u'séance', 'precedente': u'précédente', 'precedait': u'précédait',
    'deploye': u'déployé', 'deploiements': u'déploiements', 'deployees': u'déployées',
    'malgre': u'malgré', 'redeploiement': u'redéploiement', 'reparee': u'réparée',
    'desactivee': u'désactivée', 'perimee': u'périmée', 'mecanisme': u'mécanisme',
    'deplacer': u'déplacer', 'execution': u'exécution', 'theorique': u'théorique',
    'manquee': u'manquée', 'categorie': u'catégorie', 'etiquettes': u'étiquettes',
    'reglages': u'réglages', 'reactiver': u'réactiver', 'integralement': u'intégralement',
    'cloture': u'clôture', 'echouer': u'échouer', 'echouera': u'échouera',
    'etat': u'état', 'retroactivement': u'rétroactivement', 'redigee': u'rédigée',
    'redigees': u'rédigées', 'pres': u'près', 'donnees': u'données', 'decidee': u'décidée',
    'abandonnee': u'abandonnée', 'dedie': u'dédié', 'dediee': u'dédiée',
    'ecraser': u'écraser', 'independantes': u'indépendantes', 'coherent': u'cohérent',
    'derriere': u'derrière', 'melanesien': u'mélanésien', 'europeens': u'européens',
    'polynesien': u'polynésien', 'clarifiee': u'clarifiée', 'tete': u'tête',
    'recurrent': u'récurrent', 'recurrents': u'récurrents', 'regeneration': u'régénération',
    'entiere': u'entière', 'generation': u'génération', 'reelle': u'réelle', 'reel': u'réel',
    'scenario': u'scénario', 'parait': u'paraît', 'recupere': u'récupère',
    'decalee': u'décalée', 'connaitre': u'connaître', 'memoire': u'mémoire',
    'ajoutes': u'ajoutés', 'interpretent': u'interprètent', 'differemment': u'différemment',
    'reutiliser': u'réutiliser', 'ramenee': u'ramenée', 'arretee': u'arrêtée',
    'creations': u'créations', 'retires': u'retirés', 'activite': u'activité',
    'activites': u'activités', 'derapage': u'dérapage', 'deuxieme': u'deuxième',
    'resultat': u'résultat', 'resultats': u'résultats', 'bloquees': u'bloquées',
    'regime': u'régime', 'recent': u'récent', 'utilises': u'utilisés',
    'supprimee': u'supprimée', 'supprimees': u'supprimées', 'retabli': u'rétabli',
    'terminee': u'terminée', 'reservee': u'réservée', 'operationnelle': u'opérationnelle',
    'operationnel': u'opérationnel', 'modele': u'modèle', 'apres': u'après',
    'meme': u'même', 'memes': u'mêmes', 'decision': u'décision', 'decisions': u'décisions',
    'complete': u'complète', 'completee': u'complétée', 'periode': u'période',
    'derniere': u'dernière', 'dernieres': u'dernières', 'premiere': u'première',
    'numerotation': u'numérotation', 'anteriorite': u'antériorité', 'anterieures': u'antérieures',
    'anterieure': u'antérieure', 'securite': u'sécurité', 'necessaire': u'nécessaire',
    'element': u'élément', 'elements': u'éléments', 'evite': u'évite', 'eviter': u'éviter',
    'evenement': u'événement', 'present': u'présent', 'presente': u'présente',
    'interet': u'intérêt', 'succes': u'succès', 'acces': u'accès', 'proces': u'procès',
    'tres': u'très', 'apres-midi': u'après-midi', 'desormais': u'désormais',
    'immediatement': u'immédiatement', 'precedent': u'précédent', 'precedents': u'précédents',
    'ete': u'été', 'salaries': u'salariés', 'publiee': u'publiée', 'publiees': u'publiées',
    'retention': u'rétention', 'operations': u'opérations', 'operation': u'opération',
    'numero': u'numéro', 'numeros': u'numéros', 'defaut': u'défaut', 'defauts': u'défauts',
    'reussi': u'réussi', 'reussie': u'réussie', 'reussite': u'réussite',
    'realise': u'réalisé', 'realisee': u'réalisée', 'realite': u'réalité',
    'repetition': u'répétition', 'resume': u'résumé', 'reference': u'référence',
    'references': u'références', 'strategie': u'stratégie', 'strategique': u'stratégique',
    'economique': u'économique', 'economiques': u'économiques', 'eco': u'éco',
    'deriere': u'derrière', 'evidence': u'évidence', 'etendu': u'étendu',
    'incoherence': u'incohérence', 'coherence': u'cohérence', 'integre': u'intégré',
    'integrer': u'intégrer', 'delai': u'délai', 'delais': u'délais',
    'procedure': u'procédure', 'systeme': u'système', 'systemes': u'systèmes',
    'probleme': u'problème', 'problemes': u'problèmes', 'modifie': u'modifié',
    'modifiee': u'modifiée', 'repere': u'repère', 'reperes': u'repères',
    'critere': u'critère', 'criteres': u'critères', 'caracteres': u'caractères',
    'parametre': u'paramètre', 'parametres': u'paramètres', 'metier': u'métier',
    'metiers': u'métiers', 'equipe': u'équipe', 'equipes': u'équipes',
    'edition': u'édition', 'editorial': u'éditorial', 'editoriale': u'éditoriale',
}

# ---------------------------------------------------------------------------
# 2. Participes ambigus — accentues UNIQUEMENT derriere un auxiliaire
# ---------------------------------------------------------------------------
AMBIGUS = {
    'remplace': u'remplacé', 'passe': u'passé', 'ajoute': u'ajouté', 'exige': u'exigé',
    'traite': u'traité', 'corrige': u'corrigé', 'consomme': u'consommé', 'reporte': u'reporté',
    'termine': u'terminé', 'calcule': u'calculé', 'recopie': u'recopié', 'deplace': u'déplacé',
    'redresse': u'redressé', 'affiche': u'affiché', 'compare': u'comparé', 'demarre': u'démarré',
    'releve': u'relevé', 'ecarte': u'écarté', 'regarde': u'regardé', 'supprime': u'supprimé',
    'exporte': u'exporté', 'marque': u'marqué', 'decide': u'décidé', 'libere': u'libéré',
    'souleve': u'soulevé', 'evalue': u'évalué', 'reserve': u'réservé', 'declenche': u'déclenché',
    'publie': u'publié', 'annule': u'annulé', 'signale': u'signalé', 'occupe': u'occupé',
    'inscrit': u'inscrit', 'conserve': u'conservé', 'pousse': u'poussé',
}

AUX = r"(?:est|sont|a|ont|a\s+été|ont\s+été|était|étaient|avait|avaient|sera|seront|serait|" \
      r"soit|été|étant|fut|furent|s'est|s'était|n'est|n'était|n'a|n'avait)"


# Identifiants techniques a NE JAMAIS toucher : noms de routines et de workflows
# (perfeco-verif-github-actions), noms de fichiers (jeudi.json, publish-mardi.yml),
# URLs, cles JSON. Un accent dedans casserait la reference.
# Bug reel du 16/09/2026 : « perfeco-verif-github-actions » etait devenu
# « perfeco-vérif-github-actions » a la premiere simulation.
MASQUES = re.compile(
    r"(https?://\S+"                      # URLs
    r"|[A-Za-z0-9_-]+\.(?:json|yml|yaml|ps1|py|md|html|cjs|js|png|docx|txt|jsonl)"  # fichiers, tirets compris
    r"|[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)+"  # kebab-case et snake_case, MAJUSCULES COMPRISES
    r"|#[0-9A-Fa-f]{6}"                   # couleurs
    r"|§\d+\w*)"                          # renvois de section
)


def accentue(t):
    # 0. mettre a l abri les identifiants techniques
    coffre = []

    def garde(m):
        coffre.append(m.group(0))
        return u'\x00%d\x00' % (len(coffre) - 1)

    t = MASQUES.sub(garde, t)

    # 1. mots non ambigus
    def rep(m):
        w = m.group(0)
        bas = w.lower()
        if bas not in MOTS:
            return w
        acc = MOTS[bas]
        return acc.upper() if w.isupper() else (acc[0].upper() + acc[1:] if w[0].isupper() else acc)
    t = re.sub(r"\b[A-Za-z]{3,}\b", rep, t)

    # 2. participes ambigus, uniquement derriere un auxiliaire
    for brut, acc in AMBIGUS.items():
        t = re.sub(r"(\b%s\s+(?:pas\s+|plus\s+|jamais\s+|deja\s+|déjà\s+)?)%s\b" % (AUX, brut),
                   lambda m, a=acc: m.group(1) + a, t)

    # 3. elisions : « l erreur » -> « l'erreur »
    t = re.sub(r"\b([ldnjcms]) ([aeiouéèêàhA-Z])", r"\1'\2", t)

    # 4. rendre les identifiants techniques
    t = re.sub(r"\x00(\d+)\x00", lambda m: coffre[int(m.group(1))], t)
    return t


def main():
    ecrire = '--ecrire' in sys.argv
    data = json.loads(io.open(REGISTRE, encoding='utf-8', newline='').read(),
                      object_pairs_hook=collections.OrderedDict)
    n = 0
    apercu = []
    for pub in data['publications']:
        av = pub.get('note')
        if not av:
            continue
        ap = accentue(av)
        if ap != av:
            n += 1
            if len(apercu) < 4:
                apercu.append((pub.get('date_nc'), ap[:300]))
            if ecrire:
                pub['note'] = ap
    for date, txt in apercu:
        print(u'  %s : %s' % (date, txt))
        print(u'')
    print(u'%d note(s) modifiee(s) sur %d' %
          (n, sum(1 for p in data['publications'] if p.get('note'))))
    if ecrire:
        io.open(REGISTRE, 'w', encoding='utf-8', newline='').write(
            json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        print(u'REGISTRE ECRIT')
    else:
        print(u'SIMULATION - rien ecrit.')


if __name__ == '__main__':
    main()
