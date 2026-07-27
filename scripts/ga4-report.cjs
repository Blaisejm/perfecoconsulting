#!/usr/bin/env node
// Collecte GA4 (sessions, users, pageviews, bounce_rate, top 5 pages) pour perfeco.nc + perfsystemique.fr
// Utilise le compte de service via la variable d'env GA4_SERVICE_ACCOUNT_JSON (secret GitHub, contenu JSON complet)
// Sortie : un objet JSON sur stdout — { ga4_perfeco, ga4_perfsystemique }
// Ne jamais faire échouer le process sur une erreur GA4 — écrire un objet avec error à la place.

const crypto = require('crypto');
const https = require('https');

const PROPERTY_PERFECO = '539661118';
const PROPERTY_PERFSYSTEMIQUE = '537301737';

function base64url(input) {
  return Buffer.from(input).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data || '{}') }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function getAccessToken(creds) {
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64url(JSON.stringify({
    iss: creds.client_email,
    scope: 'https://www.googleapis.com/auth/analytics.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }));
  const signInput = `${header}.${payload}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signInput);
  signer.end();
  const signature = signer.sign(creds.private_key);
  const sig = signature.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const jwt = `${signInput}.${sig}`;

  const body = `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${encodeURIComponent(jwt)}`;
  const res = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) }
  }, body);
  if (!res.body.access_token) throw new Error('Échec obtention token Google : ' + JSON.stringify(res.body));
  return res.body.access_token;
}

async function runReport(token, propertyId, body) {
  const data = JSON.stringify(body);
  const res = await httpsRequest({
    hostname: 'analyticsdata.googleapis.com',
    path: `/v1beta/properties/${propertyId}:runReport`,
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
  }, data);
  return res.body;
}

async function getSiteStats(token, propertyId) {
  const stats = { sessions: 0, users: 0, pageviews: 0, bounce_rate: 0, top_pages: [] };

  const main = await runReport(token, propertyId, {
    dateRanges: [{ startDate: '7daysAgo', endDate: 'yesterday' }],
    metrics: [{ name: 'sessions' }, { name: 'activeUsers' }, { name: 'screenPageViews' }, { name: 'bounceRate' }]
  });
  if (main.rows && main.rows[0]) {
    const r = main.rows[0].metricValues;
    stats.sessions = parseInt(r[0].value, 10);
    stats.users = parseInt(r[1].value, 10);
    stats.pageviews = parseInt(r[2].value, 10);
    stats.bounce_rate = Math.round(parseFloat(r[3].value) * 1000) / 10;
  }

  const pages = await runReport(token, propertyId, {
    dateRanges: [{ startDate: '7daysAgo', endDate: 'yesterday' }],
    metrics: [{ name: 'screenPageViews' }],
    dimensions: [{ name: 'pagePath' }],
    limit: 5,
    orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }]
  });
  if (pages.rows) {
    stats.top_pages = pages.rows.map(row => ({
      path: row.dimensionValues[0].value,
      pageviews: parseInt(row.metricValues[0].value, 10)
    }));
  }

  return stats;
}

(async () => {
  try {
    const creds = JSON.parse(process.env.GA4_SERVICE_ACCOUNT_JSON);
    const token = await getAccessToken(creds);
    const perfeco = await getSiteStats(token, PROPERTY_PERFECO);
    const perfsystemique = await getSiteStats(token, PROPERTY_PERFSYSTEMIQUE);
    console.log(JSON.stringify({ ga4_perfeco: perfeco, ga4_perfsystemique: perfsystemique }));
  } catch (err) {
    console.error('ERREUR GA4 (non bloquant) :', err.message);
    console.log(JSON.stringify({ ga4_perfeco: null, ga4_perfsystemique: null, error: err.message }));
  }
})();
