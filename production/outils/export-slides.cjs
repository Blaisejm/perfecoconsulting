// ---------------------------------------------------------------------------
// EXPORT DES SLIDES EN PNG — version cloud (étape 4 de la diffusion 100 % cloud,
// 22/11/2026). Reprend à l'identique export-slides.cjs / export-v2.cjs de l'outil
// local perfeco-publisher-mcp, mais SANS chemin Windows codé en dur : le fichier
// HTML, le dossier de sortie et les noms des slides sont passés en arguments, pour
// tourner dans GitHub Actions comme sur le PC.
//
// Usage :
//   node production/outils/export-slides.cjs <fichier.html> <dossier-sortie> [nom1,nom2,...]
//   (dépendance : npm install --no-save puppeteer)
//
// Règles conservées (feedback « Puppeteer slides export ») : args obligatoires,
// attente de TOUTES les images, et ABANDON si une seule image n'a pas chargé —
// mieux vaut pas de slides que des slides sans photo ou sans logo (règle du 08/07,
// contrôle ajouté le 23/09/2026).
// ---------------------------------------------------------------------------
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const [htmlArg, outArg, nomsArg] = process.argv.slice(2);
if (!htmlArg || !outArg) {
  console.error('Usage : node production/outils/export-slides.cjs <fichier.html> <dossier-sortie> [nom1,nom2,...]');
  process.exit(2);
}
const HTML_FILE = path.resolve(htmlArg);
const OUTPUT_DIR = path.resolve(outArg);
const SLIDE_NAMES = nomsArg ? nomsArg.split(',').map(s => s.trim()).filter(Boolean) : [];

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--allow-file-access-from-files', '--disable-web-security', '--no-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1600, height: 900, deviceScaleFactor: 2 });
  await page.goto('file://' + (HTML_FILE.startsWith('/') ? '' : '/') + HTML_FILE.replace(/\\/g, '/'),
    { waitUntil: 'networkidle0', timeout: 30000 });

  await page.evaluate(() => Promise.all(
    Array.from(document.images).map(img =>
      img.complete ? Promise.resolve() : new Promise(r => { img.onload = img.onerror = r; })
    )
  ));
  await new Promise(r => setTimeout(r, 2000));

  // img.complete passe à true même quand le chargement a ÉCHOUÉ : on vérifie la largeur réelle.
  const images = await page.evaluate(() =>
    Array.from(document.images).map(i => ({ src: i.getAttribute('src'), w: i.naturalWidth }))
  );
  const cassees = images.filter(i => i.w === 0);
  console.log(`${images.length} image(s) vérifiée(s), ${images.length - cassees.length} chargée(s).`);
  if (cassees.length) {
    console.error(`\n❌ ${cassees.length} image(s) NON chargée(s) — export abandonné :`);
    for (const i of cassees) console.error(`   ${i.src}`);
    console.error('\nVérifier les chemins (relatifs au fichier HTML), et que https://www.perfeco.nc répond pour le logo.');
    await browser.close();
    process.exit(1);
  }

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const slides = await page.$$('.slide');
  console.log(`Trouvé ${slides.length} slides`);
  if (!slides.length) { console.error('❌ Aucun élément .slide dans la page.'); await browser.close(); process.exit(1); }
  if (SLIDE_NAMES.length && SLIDE_NAMES.length !== slides.length) {
    console.warn(`⚠️ ${SLIDE_NAMES.length} nom(s) fourni(s) pour ${slides.length} slide(s) — les slides sans nom seront numérotées.`);
  }

  for (let i = 0; i < slides.length; i++) {
    const filename = `${SLIDE_NAMES[i] || `slide-${String(i + 1).padStart(2, '0')}`}.png`;
    await slides[i].screenshot({ path: path.join(OUTPUT_DIR, filename), type: 'png' });
    console.log(`✅ ${filename}`);
  }
  await browser.close();
  console.log(`\n✅ ${slides.length} slides exportées dans : ${OUTPUT_DIR}`);
})();
