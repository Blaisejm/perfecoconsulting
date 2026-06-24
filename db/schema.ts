import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

// Demandes de contact reçues via le formulaire du site perfeco.nc
export const leads = pgTable("leads", {
  id: serial().primaryKey(),
  nom: text().notNull(),
  email: text().notNull(),
  organisation: text(),
  message: text().notNull(),
  langue: text().notNull().default("fr"),
  createdAt: timestamp("created_at").defaultNow(),
});
