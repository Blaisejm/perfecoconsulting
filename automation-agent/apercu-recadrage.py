#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aperçu du RECADRAGE d'un visuel par les plateformes, à regarder AVANT la mise en file.

Règle de la zone sûre (Jean-Michel, 18/11/2026, critique de la couverture I1 :
« le texte est trop à gauche et semble trop peu lisible en raison du découpage ») :
Facebook (ordinateur, vignette de Page) recadre un 4:5 en CARRÉ central, et LinkedIn
recadre la couverture d'un post multi-images en mosaïque. Ce qu'on regarde sur
l'image source n'est donc PAS ce que voit le lecteur.

Usage :
  python -X utf8 apercu-recadrage.py <image.png> [dossier_sortie]

Produit, à côté de l'image (ou dans dossier_sortie) :
  <nom>-apercu-carre.png      carré central (vue Facebook ordinateur / vignette)
  <nom>-apercu-mosaique.png   bande centrale 2:3 en largeur (couverture d'une mosaïque LinkedIn)
Puis regarde les DEUX fichiers avec l'outil Read : le titre principal, le logo et
le sous-titre doivent y être entiers, lisibles, et pas collés à un bord.
Code de sortie 0 ; 2 si l'image est introuvable.
"""
import os
import sys

from PIL import Image


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    if not os.path.exists(src):
        print(f"ERREUR : image introuvable : {src}")
        sys.exit(2)
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(src))
    os.makedirs(out, exist_ok=True)
    base = os.path.splitext(os.path.basename(src))[0]
    im = Image.open(src).convert("RGB")
    w, h = im.size

    # 1. Carré central
    c = min(w, h)
    carre = im.crop(((w - c) // 2, (h - c) // 2, (w - c) // 2 + c, (h - c) // 2 + c))
    p1 = os.path.join(out, f"{base}-apercu-carre.png")
    carre.save(p1)

    # 2. Mosaïque LinkedIn : la couverture occupe ~2/3 de la largeur du cadre,
    #    à la hauteur du cadre ; on garde donc une bande centrale de ratio 2:3 (l:h)
    #    de la hauteur totale — approximation volontairement pessimiste.
    bw = min(w, int(h * 2 / 3 * 0.92))
    mosaique = im.crop(((w - bw) // 2, 0, (w - bw) // 2 + bw, h))
    p2 = os.path.join(out, f"{base}-apercu-mosaique.png")
    mosaique.save(p2)

    print(f"Image source : {w}x{h}")
    print(f"  carré (Facebook)       : {p1}")
    print(f"  mosaïque (LinkedIn)    : {p2}")
    print("=> Regarde les deux aperçus : titre, logo et sous-titre entiers et lisibles ?")


if __name__ == "__main__":
    main()
