// Meu Pet+ — envio de notificações push (Cloudflare Worker, plano grátis).
//
// O app chama POST /notify com o login do Firebase (ID token) e a lista de
// usuários a avisar. O Worker confere o login, busca os tokens dos aparelhos
// no Firestore e envia pelo Firebase Cloud Messaging (FCM HTTP v1).
//
// Configuração no painel do Cloudflare (Settings → Variables and Secrets):
//   SERVICE_ACCOUNT  (Secret)  conteúdo do JSON da conta de serviço do Firebase
//   PROJECT_ID       (Text)    meupet-2c05b

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

let cachedAccess = null; // { token, exp }
let cachedJwks = null; // { keys, exp }

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    if (url.pathname === '/' && req.method === 'GET') return json({ ok: true, service: 'meupet-push' });
    if (url.pathname !== '/notify' || req.method !== 'POST') return json({ error: 'not found' }, 404);

    const projectId = env.PROJECT_ID || 'meupet-2c05b';
    let sender;
    try {
      const idToken = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
      sender = await verifyIdToken(idToken, projectId);
    } catch (e) {
      return json({ error: 'unauthorized', detail: String(e.message || e) }, 401);
    }

    let body;
    try {
      body = await req.json();
    } catch {
      return json({ error: 'bad json' }, 400);
    }
    const to = [...new Set((Array.isArray(body.to) ? body.to : []).filter((x) => typeof x === 'string' && x && x !== sender))].slice(0, 200);
    const title = String(body.title || 'Meu Pet+').slice(0, 120);
    const text = String(body.body || '').slice(0, 400);
    const data = {};
    for (const [k, v] of Object.entries(body.data || {}).slice(0, 12)) data[String(k).slice(0, 40)] = String(v).slice(0, 300);
    data.from = sender;
    const channel = data.channel === 'sos' ? 'sos' : 'meupet';

    const sa = JSON.parse(env.SERVICE_ACCOUNT);
    const access = await getAccessToken(sa);
    let sent = 0;
    let failed = 0;
    for (const uid of to) {
      const tokens = await getTokens(projectId, uid, access);
      const stale = [];
      for (const token of tokens) {
        const r = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body: text },
              data,
              android: {
                priority: 'HIGH',
                notification: { channel_id: channel, sound: 'default', icon: 'ic_stat_meupet', color: '#1B9AAA' },
              },
            },
          }),
        });
        if (r.ok) {
          sent++;
        } else {
          failed++;
          const err = await r.text();
          if (r.status === 404 || err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')) stale.push(token);
        }
      }
      if (stale.length) await removeTokens(projectId, uid, tokens.filter((t) => !stale.includes(t)), access);
    }
    return json({ sent, failed });
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS } });
}

// ---------------------------------------------------------------- base64url
function b64urlToBytes(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToB64url(bytes) {
  let bin = '';
  const arr = new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
const enc = new TextEncoder();
const strToB64url = (s) => bytesToB64url(enc.encode(s));

// ---------------------------------------------------------------- login do Firebase
async function verifyIdToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('token inválido');
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1])));
  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== 'RS256') throw new Error('alg');
  if (payload.aud !== projectId) throw new Error('aud');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('iss');
  if (!payload.sub || payload.exp < now || payload.iat > now + 300) throw new Error('expirado');

  if (!cachedJwks || cachedJwks.exp < Date.now()) {
    const r = await fetch(JWKS_URL);
    const maxAge = Number((r.headers.get('cache-control') || '').match(/max-age=(\d+)/)?.[1] || 3600);
    cachedJwks = { keys: (await r.json()).keys, exp: Date.now() + maxAge * 1000 };
  }
  const jwk = cachedJwks.keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('kid');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64urlToBytes(parts[2]), enc.encode(`${parts[0]}.${parts[1]}`));
  if (!ok) throw new Error('assinatura');
  return payload.sub;
}

// ---------------------------------------------------------------- conta de serviço → OAuth
async function getAccessToken(sa) {
  if (cachedAccess && cachedAccess.exp > Date.now() + 60000) return cachedAccess.token;
  const now = Math.floor(Date.now() / 1000);
  const head = strToB64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = strToB64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${head}.${claims}`));
  const jwt = `${head}.${claims}.${bytesToB64url(sig)}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`,
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('oauth: ' + JSON.stringify(j));
  cachedAccess = { token: j.access_token, exp: Date.now() + (j.expires_in || 3600) * 1000 };
  return cachedAccess.token;
}

// ---------------------------------------------------------------- Firestore (tokens dos aparelhos)
const docUrl = (projectId, uid) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;

async function getTokens(projectId, uid, access) {
  const r = await fetch(`${docUrl(projectId, uid)}?mask.fieldPaths=fcmTokens`, { headers: { Authorization: `Bearer ${access}` } });
  if (!r.ok) return [];
  const doc = await r.json();
  return (doc.fields?.fcmTokens?.arrayValue?.values || []).map((v) => v.stringValue).filter(Boolean).slice(0, 10);
}

async function removeTokens(projectId, uid, keep, access) {
  await fetch(`${docUrl(projectId, uid)}?updateMask.fieldPaths=fcmTokens`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { fcmTokens: { arrayValue: { values: keep.map((t) => ({ stringValue: t })) } } } }),
  });
}
