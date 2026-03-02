import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const onRequest: PagesFunction = async (context) => {
  const { request, env } = context;
  const supabase = getSupabase(env);

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

  try {
    const body = await request.json() as any;
    const { tripId, fileName, mimeType, data, linkedItem, category } = body;

    if (!tripId || !fileName || !data) {
      return new Response(JSON.stringify({ error: 'tripId, fileName, data required' }), { status: 400, headers: cors });
    }

    const binaryStr = atob(data);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);

    const storagePath = `${tripId}/${Date.now()}_${fileName}`;
    const { error: uploadError } = await supabase.storage.from('attachments').upload(storagePath, bytes.buffer, {
      contentType: mimeType || 'application/octet-stream', upsert: false,
    });
    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage.from('attachments').getPublicUrl(storagePath);

    const { data: record, error } = await supabase.from('attachments').insert({
      trip_id: tripId, file_name: fileName, file_type: mimeType || 'application/octet-stream',
      file_size: bytes.length, storage_path: storagePath,
      ...(linkedItem ? { linked_item: linkedItem } : {}),
      ...(category ? { category } : {}),
    }).select().single();
    if (error) throw error;

    return new Response(JSON.stringify({ ...record, url: urlData.publicUrl }), { status: 201, headers: cors });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
  }
};
