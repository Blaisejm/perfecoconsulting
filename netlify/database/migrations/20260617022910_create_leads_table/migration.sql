CREATE TABLE "leads" (
	"id" serial PRIMARY KEY,
	"nom" text NOT NULL,
	"email" text NOT NULL,
	"organisation" text,
	"message" text NOT NULL,
	"langue" text DEFAULT 'fr' NOT NULL,
	"created_at" timestamp DEFAULT now()
);
