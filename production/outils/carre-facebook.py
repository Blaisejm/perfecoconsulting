#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VARIANTE FACEBOOK CARRÉE 1200×1200 (22/11/2026, demande de Jean-Michel : « agrandir le logo de
PerfEco et adapter les images … améliorer les parutions notamment FB » — points A-2026-11-22-08
et A-2026-11-22-09).

Facebook affiche un 4:5 rétréci entre deux bandes, logo minuscule. Le carré occupe tout le cadre :
  - moitié haute : la PHOTO DE GROUPE, sans voile (le groupe se voit toujours) ;
  - moitié basse : bandeau bleu PerfEco, petit libellé or, TITRE centré, sous-titre, et le LOGO
    agrandi (≥ 18 % de la largeur, 240 px sur 1200), dans la zone sûre.

Usage :
  python3 production/outils/carre-facebook.py --photo <chemin relatif depuis --sortie-html>
      --titre "Au retour de formation,|une décision sans vous" [--accent 2]
      [--libelle "Nouvelle-Calédonie · CCI-NC"] [--chiffre "3 657"] [--sous-titre "…"]
      [--position "50% 35%"] --sortie-html <dossier>/<nom>-carre.html
  puis : node production/outils/export-slides.cjs <html> <dossier> 00-facebook-carre-<slug>

  --titre : lignes séparées par « | » ; --accent N : les N dernières lignes en or.
Aucun emoji (Puppeteer ne les affiche pas). Les espaces dans les nombres deviennent insécables.
"""
import argparse
import html
import os
import re


def insecables(t):
    t = re.sub(r"(\d) (\d{3})", "\\1&nbsp;\\2", t)
    return t.replace(" %", "&nbsp;%").replace(" :", "&nbsp;:").replace(" ?", "&nbsp;?").replace(" !", "&nbsp;!")


def esc(t):
    return insecables(html.escape(t, quote=False))


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--photo", required=True)
    a.add_argument("--titre", required=True)
    a.add_argument("--accent", type=int, default=1)
    a.add_argument("--libelle", default="")
    a.add_argument("--chiffre", default="")
    a.add_argument("--sous-titre", default="")
    a.add_argument("--position", default="50% 35%")
    a.add_argument("--sortie-html", required=True)
    o = a.parse_args()

    lignes = [l.strip() for l in o.titre.split("|") if l.strip()]
    n_or = max(0, min(o.accent, len(lignes)))
    titre = "<br>".join(
        (f'<span class="accent">{esc(l)}</span>' if i >= len(lignes) - n_or else esc(l))
        for i, l in enumerate(lignes))
    libelle = f'<div class="libelle">{esc(o.libelle)}</div>' if o.libelle else ""
    chiffre = f'<div class="chiffre">{esc(o.chiffre)}</div>' if o.chiffre else ""
    sous = f'<p class="sous-titre">{esc(o.sous_titre)}</p>' if o.sous_titre else ""

    page = f"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8"><title>Facebook carré</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Arial', sans-serif; background: #d0d0d0; }}
  .slide {{ width: 1200px; height: 1200px; position: relative; overflow: hidden; margin: 24px auto; background: #001D9F; }}
  .photo {{ position: absolute; left: 0; top: 0; width: 1200px; height: 560px; }}
  .photo img {{ width: 100%; height: 100%; object-fit: cover; object-position: {o.position}; display: block; }}
  .photo::after {{ content: ""; position: absolute; left: 0; right: 0; bottom: 0; height: 90px;
                   background: linear-gradient(180deg, rgba(0,29,159,0) 0%, rgba(0,29,159,1) 100%); }}
  .bandeau {{ position: absolute; left: 0; top: 560px; width: 1200px; height: 640px;
              padding: 34px 132px 56px; display: flex; flex-direction: column; align-items: center;
              text-align: center; background: #001D9F; }}
  .libelle {{ color: #FBAA16; font-size: 20px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; }}
  .chiffre {{ color: #FBAA16; font-size: 36px; font-weight: 800; line-height: 1.2; margin-top: 14px; }}
  .titre {{ color: #fff; font-size: 62px; font-weight: 900; line-height: 1.16; margin-top: 18px; letter-spacing: -0.5px; }}
  .titre .accent {{ color: #FBAA16; }}
  .sous-titre {{ color: #fff; font-size: 27px; font-weight: 600; line-height: 1.5; margin-top: 18px; }}
  .logo {{ margin-top: auto; }}
  .logo img {{ width: 240px; filter: brightness(0) invert(1); display: block; }}  /* logo recadré du site : 240 px visibles */
</style></head><body>
<div class="slide">
  <div class="photo"><img src="{html.escape(o.photo)}" alt=""></div>
  <div class="bandeau">
    {libelle}
    {chiffre}
    <h1 class="titre">{titre}</h1>
    {sous}
    <div class="logo"><img src="https://www.perfeco.nc/logo-perfeco-site.svg" alt="PerfEco"></div>
  </div>
</div>
</body></html>
"""
    os.makedirs(os.path.dirname(os.path.abspath(o.sortie_html)), exist_ok=True)
    with open(o.sortie_html, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print(o.sortie_html)


if __name__ == "__main__":
    main()
