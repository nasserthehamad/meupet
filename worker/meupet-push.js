// Meu Pet+ — envio de notificações push (Cloudflare Worker, plano grátis).
//
// O app chama POST /notify com o login do Firebase (ID token) e a lista de
// usuários a avisar. O Worker confere o login, busca os tokens dos aparelhos
// no Firestore e envia pelo Firebase Cloud Messaging (FCM HTTP v1).
//
// Configuração no painel do Cloudflare (Settings → Variables and Secrets):
//   SERVICE_ACCOUNT  (Secret)  conteúdo do JSON da conta de serviço do Firebase
//   PROJECT_ID       (Text)    meupet-2c05b

import { seedDemo, simulateTutor } from './seed.js';

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

let cachedAccess = null; // { token, exp }
let cachedJwks = null; // { keys, exp }

export default {
  async fetch(req, env, ctx) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    if (url.pathname === '/' && req.method === 'GET') {
      // Diagnóstico: diz só se a chave existe e funciona (nunca mostra a chave).
      const out = { ok: true, service: 'meupet-push', configured: !!env.SERVICE_ACCOUNT };
      if (url.searchParams.has('check') && env.SERVICE_ACCOUNT) {
        try {
          const sa = JSON.parse(env.SERVICE_ACCOUNT);
          out.projectMatches = sa.project_id === (env.PROJECT_ID || 'meupet-2c05b');
          out.google = !!(await getAccessToken(sa));
        } catch (e) {
          out.google = false;
          out.error = String(e.message || e).slice(0, 120).replace(/-----BEGIN[\s\S]*/, '');
        }
      }
      return json(out);
    }
    const isSeed = url.pathname === '/seed';
    const isTest = url.pathname === '/test';
    if ((url.pathname !== '/notify' && !isSeed && !isTest) || req.method !== 'POST') return json({ error: 'not found' }, 404);

    const projectId = env.PROJECT_ID || 'meupet-2c05b';
    let sender;
    let who;
    try {
      const idToken = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
      who = await verifyIdToken(idToken, projectId);
      sender = who.sub;
    } catch (e) {
      console.log(JSON.stringify({ ev: 'auth_fail', path: url.pathname, err: String(e.message || e) }));
      return json({ error: 'unauthorized', detail: String(e.message || e) }, 401);
    }

    // Teste: manda uma notificação para os aparelhos da própria conta, depois
    // de alguns segundos (dá tempo de sair do app e ver na barra do celular).
    if (isTest) {
      const access = await getAccessToken(JSON.parse(env.SERVICE_ACCOUNT));
      const tokens = await getTokens(projectId, sender, access);
      const delay = Math.min(15, Math.max(0, Number(url.searchParams.get('delay') || 6))) * 1000;
      const run = async () => {
        await new Promise((r) => setTimeout(r, delay));
        const res = await sendTo([sender], '🐾 Teste do Meu Pet+', 'Se você está vendo isto, as notificações estão funcionando!', { type: 'test' }, 'meupet', projectId, access);
        console.log(JSON.stringify({ ev: 'test', uid: sender, ...res }));
        // Conta de teste do tutor: em seguida, notificações de exemplo de verdade.
        const allowed = String(env.SEED_EMAILS || '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
        if (who.email && allowed.includes(String(who.email).toLowerCase())) {
          try {
            await simulateTutor({
              projectId,
              uid: sender,
              email: who.email,
              access,
              pause: () => new Promise((r) => setTimeout(r, 3000)),
              send: async (title, body, data) => {
                await new Promise((r) => setTimeout(r, 0));
                const out = await sendTo([sender], title, body, data, 'meupet', projectId, access);
                console.log(JSON.stringify({ ev: 'simulate', type: data.type, uid: sender, ...out }));
              },
            });
          } catch (e) {
            console.log(JSON.stringify({ ev: 'simulate_fail', err: String(e.message || e).slice(0, 300) }));
          }
        }
      };
      ctx.waitUntil(run());
      return json({ ok: true, devices: tokens.length, delay: delay / 1000 });
    }

    // Dados de demonstração: só para as contas de teste autorizadas.
    if (isSeed) {
      const allowed = String(env.SEED_EMAILS || '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
      if (!who.email || !allowed.includes(String(who.email).toLowerCase())) return json({ error: 'forbidden' }, 403);
      try {
        const access = await getAccessToken(JSON.parse(env.SERVICE_ACCOUNT));
        return json({ ok: true, ...(await seedDemo({ projectId, uid: sender, email: who.email, access })) });
      } catch (e) {
        return json({ error: 'seed', detail: String(e.message || e).slice(0, 400) }, 500);
      }
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

    const access = await getAccessToken(JSON.parse(env.SERVICE_ACCOUNT));
    const res = await sendTo(to, title, text, data, channel, projectId, access);
    console.log(JSON.stringify({ ev: 'notify', from: sender, type: data.type || '', ...res }));
    return json(res);
  },
};

/// Envia para todos os aparelhos de cada usuário; tira tokens que não valem mais.
async function sendTo(uids, title, text, data, channel, projectId, access) {
  let sent = 0;
  let failed = 0;
  const detail = [];
  for (const uid of uids) {
    const tokens = await getTokens(projectId, uid, access);
    const stale = [];
    const errs = [];
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
        errs.push(`${r.status} ${err.slice(0, 160)}`);
        if (r.status === 404 || err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')) stale.push(token);
      }
    }
    if (stale.length) await removeTokens(projectId, uid, tokens.filter((t) => !stale.includes(t)), access);
    detail.push({ uid, devices: tokens.length, errs });
  }
  return { sent, failed, detail };
}

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
  return payload;
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
