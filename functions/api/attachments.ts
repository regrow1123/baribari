import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const onRequest: PagesFunction = async (context) => {
  const { request, env } = context;
  const supabase = getSupabase(env);
  const url = new URL(request.url);
  const tripId = url.searchParams.get('tripId');

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (!tripId) return new Response(JSON.stringify({ error: 'tripId required' }), { status: 400, headers: cors });

  const { data, error } = await supabase.from('attachments').select('*').eq('trip_id', tripId).order('created_at', { ascending: true });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: cors });

  const withUrls = (data || []).map((att: any) => {
    const { data: urlData } = supabase.storage.from('attachments').getPublicUrl(att.storage_path);
    return { ...att, url: urlData.publicUrl };
  });

  return new Response(JSON.stringify(withUrls), { headers: cors });
};
