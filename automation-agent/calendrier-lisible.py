# -*- coding: utf-8 -*-
"""
Genere le CALENDRIER DES PUBLICATIONS lisible (Word + Markdown) a partir du registre
publications.json, qui reste la source unique de verite.

Cree le 15/09/2026 sur demande de Jean-Michel : « ton calendrier des publications doit etre
sauvegarde en dur sur le cloud, il y a trop de doute a ce niveau ».

Le document est REGENERE, jamais edite a la main : toute modification se fait dans
publications.json, puis on relance ce script. Il ne peut donc pas diverger du registre.

    python calendrier-lisible.py [nb_semaines]      (defaut : 16)
"""
import io, json, os, sys, datetime

ICI = os.path.dirname(os.path.abspath(__file__))
REGISTRE = os.path.join(ICI, 'publications.json')

ONEDRIVE = os.path.join(os.path.expanduser('~'), 'OneDrive', 'Documents')
SORTIE_DOCX = os.path.join(ONEDRIVE, 'PerfEco Consulting NC', 'Comm & Marketing',
                           'CALENDRIER-PUBLICATIONS-PerfEco.docx')
SORTIE_MD = os.path.join(ONEDRIVE, 'claude IA', 'Perfeco-Social-Media',
                         'CALENDRIER-PUBLICATIONS.md')

JOURS = {0: u'lundi', 1: u'mardi', 2: u'mercredi', 3: u'jeudi',
         4: u'vendredi', 5: u'samedi', 6: u'dimanche'}
MOIS = {1: u'janvier', 2: u'février', 3: u'mars', 4: u'avril', 5: u'mai', 6: u'juin', 7: u'juillet',
        8: u'août', 9: u'septembre', 10: u'octobre', 11: u'novembre', 12: u'décembre'}

# La campagne dediee occupe le creneau du jeudi a partir de cette date (decision du 15/09/2026).
# Avant, le jeudi portait un post court rattache a l episode du mardi.
DEBUT_CAMPAGNE = u'2026-10-01'

STATUTS = {
    'prevu': u'à produire',
    'en_staging': u'produit, en attente',
    'en_file': u'en file d’attente',
    'publie': u'publié',
    'publie_hors_pipeline': u'publié (hors pipeline)',
    'annule': u'annulé',
    'echec': u'ÉCHEC',
}


def creneau(pub):
    """Le role du creneau, en clair."""
    f = pub.get('format')
    if f == 'mardi':
        return u'Institutions' if pub.get('axe') == 'institutions' else u'Série'
    if f == 'jeudi':
        if (pub.get('date_nc') or '') < DEBUT_CAMPAGNE:
            return u'Post court'
        return u'Campagne dédiée'
    if f == 'vendredi':
        return u'Veille éco'
    return f or u'?'


def charger(nb_semaines):
    with io.open(REGISTRE, encoding='utf-8') as fh:
        data = json.load(fh)
    auj = datetime.date.today()
    fin = auj + datetime.timedelta(weeks=nb_semaines)
    lignes = []
    for p in data['publications']:
        d = p.get('date_nc')
        if not d or p.get('format') == 'ferie':
            continue
        dt = datetime.date(*[int(x) for x in d.split('-')])
        if dt < auj or dt > fin:
            continue
        if p.get('statut') == 'annule':
            continue
        lignes.append((dt, p))
    lignes.sort(key=lambda t: t[0])
    return lignes, data.get('derniere_maj', '?')


def par_semaine(lignes):
    """Regroupe par semaine (lundi)."""
    out, cur, key = [], [], None
    for dt, p in lignes:
        k = dt - datetime.timedelta(days=dt.weekday())
        if k != key:
            if cur:
                out.append((key, cur))
            key, cur = k, []
        cur.append((dt, p))
    if cur:
        out.append((key, cur))
    return out


def ecrire_md(semaines, maj, nb):
    L = []
    A = L.append
    A(u'# Calendrier des publications PerfEco')
    A(u'')
    A(u'> **Document généré automatiquement — ne pas le modifier à la main.**')
    A(u'> Il est reconstruit depuis le registre `automation-agent/publications.json`, qui est la')
    A(u'> seule source de vérité. Pour changer une date ou un sujet : modifier le registre, puis')
    A(u'> relancer `python automation-agent/calendrier-lisible.py`.')
    A(u'')
    A(u'Généré le **%s** — registre à jour au **%s** — horizon **%d semaines**.'
      % (datetime.date.today().strftime('%d/%m/%Y'), maj, nb))
    A(u'')
    A(u'## Le rythme, identique chaque semaine')
    A(u'')
    A(u'| Jour | Contenu | Rattachement |')
    A(u'|---|---|---|')
    A(u'| Mardi | post long, carrousel 6 slides | série éditoriale (Série 2, puis Institutions) |')
    A(u'| Jeudi | post court, 1 visuel | campagne dédiée Performance |')
    A(u'| Vendredi | post court | veille économique |')
    A(u'')
    A(u'Publication à **11h00 (heure NC)** dans tous les cas.')
    A(u'')
    A(u'## Calendrier')
    A(u'')
    for lundi, pubs in semaines:
        A(u'### Semaine du %d %s %d' % (lundi.day, MOIS[lundi.month], lundi.year))
        A(u'')
        A(u'| Date | Jour | Créneau | Sujet | État |')
        A(u'|---|---|---|---|---|')
        for dt, p in pubs:
            A(u'| %s | %s | **%s** | %s | %s |' % (
                dt.strftime('%d/%m'), JOURS[dt.weekday()], creneau(p),
                p.get('sujet', ''), STATUTS.get(p.get('statut'), p.get('statut', ''))))
        A(u'')
    io.open(SORTIE_MD, 'w', encoding='utf-8', newline='').write(u'\n'.join(L))
    return SORTIE_MD


def ecrire_docx(semaines, maj, nb):
    from docx import Document
    from docx.shared import Pt, RGBColor, Cm
    from docx.enum.text import WD_ALIGN_PARAGRAPH

    BLEU = RGBColor(0x00, 0x1D, 0x9F)
    OR = RGBColor(0xFB, 0xAA, 0x16)

    doc = Document()
    for s in doc.sections:
        s.left_margin = s.right_margin = Cm(1.8)

    t = doc.add_paragraph()
    r = t.add_run(u'Calendrier des publications PerfEco')
    r.font.size, r.font.bold, r.font.color.rgb = Pt(22), True, BLEU

    st = doc.add_paragraph()
    r = st.add_run(u'Mardi : série  ·  Jeudi : campagne dédiée Performance  ·  Vendredi : veille économique')
    r.font.size, r.font.bold, r.font.color.rgb = Pt(11), True, OR

    w = doc.add_paragraph()
    r = w.add_run(u'Document généré automatiquement le %s à partir du registre publications.json '
                  u'(à jour au %s). Ne pas le modifier à la main : toute correction se fait dans le '
                  u'registre, puis on relance le générateur. Horizon : %d semaines. '
                  u'Publication à 11h00 heure NC.'
                  % (datetime.date.today().strftime('%d/%m/%Y'), maj, nb))
    r.font.size, r.font.italic = Pt(8.5), True

    for lundi, pubs in semaines:
        h = doc.add_paragraph()
        r = h.add_run(u'Semaine du %d %s %d' % (lundi.day, MOIS[lundi.month], lundi.year))
        r.font.size, r.font.bold, r.font.color.rgb = Pt(12), True, BLEU

        tb = doc.add_table(rows=1, cols=5)
        tb.style = 'Light Grid Accent 1'
        for i, txt in enumerate([u'Date', u'Jour', u'Créneau', u'Sujet', u'État']):
            c = tb.rows[0].cells[i].paragraphs[0].add_run(txt)
            c.font.bold, c.font.size = True, Pt(9)
        for dt, p in pubs:
            cells = tb.add_row().cells
            vals = [dt.strftime('%d/%m'), JOURS[dt.weekday()], creneau(p),
                    p.get('sujet', ''), STATUTS.get(p.get('statut'), p.get('statut', ''))]
            for i, v in enumerate(vals):
                run = cells[i].paragraphs[0].add_run(v)
                run.font.size = Pt(9)
                if i == 2:
                    run.font.bold = True
        doc.add_paragraph()

    doc.save(SORTIE_DOCX)
    return SORTIE_DOCX


def main():
    nb = int(sys.argv[1]) if len(sys.argv) > 1 else 16
    lignes, maj = charger(nb)
    sem = par_semaine(lignes)
    a = ecrire_md(sem, maj, nb)
    b = ecrire_docx(sem, maj, nb)
    print('%d semaines, %d publications' % (len(sem), len(lignes)))
    print('Markdown : %s' % a)
    print('Word     : %s' % b)


if __name__ == '__main__':
    main()
