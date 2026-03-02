import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
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
      const { data, error } = await supabase.from('expenses').select('*').eq('trip_id', tripId).order('spent_at', { ascending: true });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers: cors });
    }

    if (request.method === 'POST') {
      const body = await request.json() as any;
      const { data, error } = await supabase.from('expenses').insert({
        trip_id: tripId, amount: body.amount, currency: body.currency || 'KRW',
        category: body.category, memo: body.memo,
        day_number: body.dayNumber || null, linked_item: body.linkedItem || null,
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers: cors });
    }

    if (request.method === 'DELETE') {
      const id = url.searchParams.get('id');
      if (!id) return new Response(JSON.stringify({ error: 'id required' }), { status: 400, headers: cors });
      const { error } = await supabase.from('expenses').delete().eq('id', id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), { headers: cors });
    }

    return new Response('Method not allowed', { status: 405, headers: cors });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
  }
};
