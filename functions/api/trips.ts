import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const onRequest: PagesFunction = async (context) => {
  const { request, env } = context;
  const supabase = getSupabase(env);
  const url = new URL(request.url);

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

  try {
    if (request.method === 'GET') {
      const { data, error } = await supabase.from('trips').select('*').order('updated_at', { ascending: false });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers: cors });
    }

    if (request.method === 'POST') {
      const body = await request.json() as any;
      const { data, error } = await supabase.from('trips').insert({
        title: body.title || '새 여행',
        destination: body.destination,
        start_date: body.start_date,
        end_date: body.end_date,
        status: body.status || 'planning',
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers: cors });
    }

    if (request.method === 'PUT') {
      const tripId = url.searchParams.get('id');
      if (!tripId) return new Response(JSON.stringify({ error: 'id required' }), { status: 400, headers: cors });
      const body = await request.json() as any;
      const { data, error } = await supabase.from('trips').update(body).eq('id', tripId).select().single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers: cors });
    }

    if (request.method === 'DELETE') {
      const tripId = url.searchParams.get('id');
      if (!tripId) return new Response(JSON.stringify({ error: 'id required' }), { status: 400, headers: cors });
      const { error } = await supabase.from('trips').delete().eq('id', tripId);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), { headers: cors });
    }

    return new Response('Method not allowed', { status: 405, headers: cors });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
  }
};
