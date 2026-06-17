import type { Config } from "@netlify/functions";
import { desc } from "drizzle-orm";
import { db } from "../../db/index.js";
import { leads } from "../../db/schema.js";

// Validation basique du format email
function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default async (req: Request) => {
  // Liste des demandes enregistrées (usage interne)
  if (req.method === "GET") {
    const all = await db.select().from(leads).orderBy(desc(leads.createdAt));
    return Response.json(all);
  }

  // Enregistrement d'une nouvelle demande de contact
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const { nom, email, organisation, message, langue, honeypot } = body;

      // Protection anti-bot : le champ honeypot doit être vide
      if (honeypot) {
        return Response.json({ success: true });
      }

      if (!nom || !email || !message) {
        return Response.json({ error: "Champs manquants" }, { status: 400 });
      }

      if (!isValidEmail(email)) {
        return Response.json({ error: "Email invalide" }, { status: 400 });
      }

      if (nom.length > 100 || email.length > 200 || message.length > 5000) {
        return Response.json({ error: "Données trop longues" }, { status: 400 });
      }

      const [lead] = await db
        .insert(leads)
        .values({
          nom,
          email,
          organisation: organisation || null,
          message,
          langue: langue === "en" ? "en" : "fr",
        })
        .returning();

      return Response.json(lead, { status: 201 });
    } catch (err) {
      return Response.json(
        { error: err instanceof Error ? err.message : "Erreur serveur" },
        { status: 500 },
      );
    }
  }

  return new Response("Method not allowed", { status: 405 });
};

export const config: Config = {
  path: "/api/leads",
};
