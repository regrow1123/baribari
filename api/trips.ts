import { supabase } from './_lib/supabase.js';

export const config = { runtime: 'edge' };

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const tripId = url.searchParams.get('id');

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }

  try {
    // GET - list trips or get one
    if (req.method === 'GET') {
      if (tripId) {
        const { data, error } = await supabase
          .from('trips')
          .select('*')
          .eq('id', tripId)
          .single();
        if (error) throw error;
        return new Response(JSON.stringify(data), { headers });
      }
      const { data, error } = await supabase
        .from('trips')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers });
    }

    // POST - create trip
    if (req.method === 'POST') {
      const body = await req.json();
      const { data, error } = await supabase
        .from('trips')
        .insert({
          title: body.title || '새 여행',
          destination: body.destination,
          start_date: body.startDate,
          end_date: body.endDate,
          user_id: 'dummy',
        })
        .select()
        .single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers });
    }

    // DELETE
    if (req.method === 'DELETE' && tripId) {
      const { error } = await supabase.from('trips').delete().eq('id', tripId);
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true }), { headers });
    }

    return new Response('Method not allowed', { status: 405, headers });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers,
    });
  }
}
