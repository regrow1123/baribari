import { supabase } from './_lib/supabase.js';

export const config = { runtime: 'edge' };

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const tripId = url.searchParams.get('tripId');

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }

  if (!tripId) {
    return new Response(JSON.stringify({ error: 'tripId required' }), { status: 400, headers });
  }

  try {
    // GET - list messages for trip
    if (req.method === 'GET') {
      const { data, error } = await supabase
        .from('messages')
        .select('*')
        .eq('trip_id', tripId)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers });
    }

    // POST - save message
    if (req.method === 'POST') {
      const body = await req.json();
      const { data, error } = await supabase
        .from('messages')
        .insert({
          trip_id: tripId,
          role: body.role,
          content: body.content,
          message_type: body.messageType || 'text',
          metadata: body.metadata,
        })
        .select()
        .single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers });
    }

    return new Response('Method not allowed', { status: 405, headers });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers,
    });
  }
}
