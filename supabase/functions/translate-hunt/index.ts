// ═══════════════════════════════════════════════════════════════
//  Edge Function « translate-hunt » — traduction automatique DeepL
//  Appelée par l'app quand un joueur ouvre une chasse pas encore
//  traduite dans sa langue. La traduction est enregistrée pour tous.
//  Secret requis : DEEPL_API_KEY (Edge Functions > Secrets)
// ═══════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';

const LANGS = ['fr', 'en', 'de', 'nl', 'es', 'it'];
const DEEPL_TARGET: Record<string, string> = { fr: 'FR', en: 'EN-GB', de: 'DE', nl: 'NL', es: 'ES', it: 'IT' };
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

async function deepl(texts: string[], source: string, target: string): Promise<string[]> {
  const key = Deno.env.get('DEEPL_API_KEY');
  if (!key) throw new Error('DEEPL_API_KEY manquante');
  // Les clés gratuites finissent par « :fx » et utilisent un autre serveur
  const url = key.endsWith(':fx') ? 'https://api-free.deepl.com/v2/translate' : 'https://api.deepl.com/v2/translate';
  const out: string[] = [];
  for (let i = 0; i < texts.length; i += 50) {          // 50 textes maximum par requête DeepL
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Authorization': `DeepL-Auth-Key ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: texts.slice(i, i + 50),
        source_lang: source.toUpperCase(),
        target_lang: DEEPL_TARGET[target],
        formality: 'prefer_less',                         // tutoiement : ton de jeu
        preserve_formatting: true,
      }),
    });
    if (!res.ok) throw new Error(`DeepL ${res.status}: ${await res.text()}`);
    const json = await res.json();
    out.push(...json.translations.map((t: { text: string }) => t.text));
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { hunt_id, lang } = await req.json();
    if (typeof hunt_id !== 'string' || !LANGS.includes(lang)) return reply({ error: 'requete_invalide' }, 400);

    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    // Réservé aux joueurs connectés (invités compris)
    const jwt = (req.headers.get('Authorization') || '').replace('Bearer ', '');
    const { data: who } = await admin.auth.getUser(jwt);
    if (!who?.user) return reply({ error: 'non_connecte' }, 401);

    const { data: hunt } = await admin.from('hunts').select('id,name,description,lang,status').eq('id', hunt_id).maybeSingle();
    if (!hunt || hunt.status !== 'publiee') return reply({ error: 'chasse_introuvable' }, 404);
    const source = hunt.lang || 'fr';
    if (lang === source) return reply({ status: 'original' });

    const { data: existing } = await admin.from('hunt_translations').select('lang').eq('hunt_id', hunt_id).eq('lang', lang).maybeSingle();
    if (existing) return reply({ status: 'exists' });

    const { data: steps } = await admin.from('hunt_steps')
      .select('id,step_type,text,hint,answer').eq('hunt_id', hunt_id).order('step_order');

    // Tous les textes à traduire en une seule liste, puis redistribués
    const texts: string[] = [];
    const slot = (s?: string | null) => (s && s.trim() ? texts.push(s) - 1 : -1);
    const nameIdx = slot(hunt.name), descIdx = slot(hunt.description);
    const stepIdx = (steps || []).map((s) => ({
      id: s.id, text: slot(s.text), hint: slot(s.hint),
      answer: s.step_type === 'enigme' ? slot(s.answer) : -1,   // les codes QR ne se traduisent pas
    }));
    const tr = texts.length ? await deepl(texts, source, lang) : [];
    const pick = (i: number) => (i >= 0 ? tr[i] : null);

    const { error } = await admin.rpc('tw_store_auto_translation', {
      p_hunt_id: hunt_id, p_lang: lang,
      p_data: {
        name: pick(nameIdx), description: pick(descIdx),
        steps: stepIdx.map((s) => ({ step_id: s.id, text: pick(s.text), hint: pick(s.hint), answer: pick(s.answer) })),
      },
    });
    if (error) throw error;
    return reply({ status: 'translated', characters: texts.join('').length });
  } catch (e) {
    console.error(e);
    return reply({ error: String((e as Error)?.message || e) }, 500);
  }
});
