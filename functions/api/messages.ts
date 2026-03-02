import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const onRequest: PagesFunction = async (context) => {
  const { request, env } = context;
  const supabase = getSupabase(env);
  const url = new URL(request.url);
  const tripId = url.searchParams.get('tripId');

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (!tripId) return new Response(JSON.stringify({ error: 'tripId required' }), { status: 400, headers: cors });

  try {
    if (request.method === 'GET') {
      const { data, error } = await supabase.from('messages').select('*').eq('trip_id', tripId).order('created_at', { ascending: true });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers: cors });
    }

    if (request.method === 'POST') {
      const body = await request.json() as any;
      const { data, error } = await supabase.from('messages').insert({
        trip_id: tripId,
        role: body.role,
        content: body.content,
        message_type: body.message_type || body.messageType || 'text',
        metadata: body.metadata,
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers: cors });
    }

    return new Response('Method not allowed', { status: 405, headers: cors });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
  }
};
