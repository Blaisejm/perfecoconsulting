import { db } from '../../db/index.js';
import { leads } from '../../db/schema.js';

// Échappe les caractères HTML pour éviter l'injection
function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Validation basique du format email
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const body = await req.json();
    const { nom, email, organisation, message, honeypot, langue } = body;

    // Protection anti-bot : le champ honeypot doit être vide
    if (honeypot) {
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Validation des champs obligatoires
    if (!nom || !email || !message) {
      return new Response(JSON.stringify({ error: 'Champs manquants' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Validation format email
    if (!isValidEmail(email)) {
      return new Response(JSON.stringify({ error: 'Email invalide' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Limite de longueur
    if (nom.length > 100 || email.length > 200 || message.length > 5000) {
      return new Response(JSON.stringify({ error: 'Données trop longues' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Échappement HTML de tous les champs
    const safeName = escapeHtml(nom);
    const safeEmail = escapeHtml(email);
    const safeOrg = organisation ? escapeHtml(organisation) : '';
    const safeMessage = escapeHtml(message).replace(/\n/g, '<br>');

    // Enregistre la demande en base avant l'envoi de l'email,
    // afin de ne perdre aucun lead même si l'email échoue.
    try {
      await db.insert(leads).values({
        nom,
        email,
        organisation: organisation || null,
        message,
        langue: langue === 'en' ? 'en' : 'fr',
      });
    } catch (dbErr) {
      console.error('Échec de l\'enregistrement du lead :', dbErr);
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.Resend_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'PerfEco Consulting <noreply@perfeco.nc>',
        to: ['contact@perfeco.nc'],
        reply_to: email,
        subject: `Nouveau message de ${safeName}${safeOrg ? ' — ' + safeOrg : ''}`,
        html: `
          <h2>Nouveau message via perfeco.nc</h2>
          <p><strong>Nom :</strong> ${safeName}</p>
          <p><strong>Email :</strong> ${safeEmail}</p>
          ${safeOrg ? `<p><strong>Organisation :</strong> ${safeOrg}</p>` : ''}
          <p><strong>Message :</strong></p>
          <p>${safeMessage}</p>
        `,
      }),
    });

    if (!res.ok) {
      const error = await res.text();
      return new Response(JSON.stringify({ error }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};

export const config = {
  path: '/api/contact',
};
