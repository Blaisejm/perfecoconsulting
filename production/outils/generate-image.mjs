import OpenAI from "openai";
import fs from "fs";
import path from "path";

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
// Version cloud (22/11/2026) : par défaut production/images du dépôt, plus de chemin Windows.
const IMAGES_LIBRARY_PATH = process.env.IMAGES_LIBRARY_PATH || "production/images";

if (!OPENAI_API_KEY) {
  console.error("❌ OPENAI_API_KEY manquant");
  process.exit(1);
}

const [,, prompt, saveAs, subfolder = "personnages", format = "portrait", quality = "high"] = process.argv;

if (!prompt || !saveAs) {
  console.error("Usage: node generate-image.mjs <prompt> <save_as> [subfolder] [format] [quality]");
  process.exit(1);
}

// gpt-image-1 sizes: portrait=1024x1536, square=1024x1024, landscape=1536x1024
const sizeMap = { portrait: "1024x1536", square: "1024x1024", landscape: "1536x1024" };
const size = sizeMap[format] || "1024x1536";

// gpt-image-1 quality: low, medium, high, auto
const qualityMap = { hd: "high", standard: "medium" };
const resolvedQuality = qualityMap[quality] || quality;

console.log(`🎨 Génération gpt-image-1 — ${format} ${size} — qualité ${resolvedQuality}`);
console.log(`📝 Prompt : ${prompt.substring(0, 100)}...`);

const openai = new OpenAI({ apiKey: OPENAI_API_KEY });

const response = await openai.images.generate({
  model: "gpt-image-1",
  prompt,
  n: 1,
  size,
  quality: resolvedQuality,
});

const saveDir = path.join(IMAGES_LIBRARY_PATH, subfolder);
if (!fs.existsSync(saveDir)) fs.mkdirSync(saveDir, { recursive: true });

const filename = `${saveAs}.png`;
const filepath = path.join(saveDir, filename);

// gpt-image-1 retourne du base64
const b64 = response.data[0].b64_json;
if (b64) {
  fs.writeFileSync(filepath, Buffer.from(b64, "base64"));
} else if (response.data[0].url) {
  const imgBuffer = Buffer.from(await (await fetch(response.data[0].url)).arrayBuffer());
  fs.writeFileSync(filepath, imgBuffer);
} else {
  throw new Error("Aucune image dans la réponse API");
}

console.log(`\n✅ Image sauvegardée : ${filepath}`);
console.log(`📐 Format : ${size} — Qualité : ${resolvedQuality}`);
