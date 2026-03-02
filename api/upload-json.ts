import { supabase } from "./_lib/supabase.js";

export const config = { runtime: "edge" };

export default async function handler(req: Request) {
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });

  try {
    const body = await req.json();
    const { tripId, fileName, mimeType, data, linkedItem, category } = body;

    if (!tripId || !fileName || !data) {
      return new Response(JSON.stringify({ error: "tripId, fileName, data required" }), { status: 400, headers });
    }

    // Decode base64
    const binaryStr = atob(data);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // Upload to Storage
    const storagePath = `${tripId}/${Date.now()}_${fileName}`;
    const { error: uploadError } = await supabase.storage
      .from("attachments")
      .upload(storagePath, bytes.buffer, {
        contentType: mimeType || "application/octet-stream",
        upsert: false,
      });

    if (uploadError) throw uploadError;

    // Get public URL
    const { data: urlData } = supabase.storage
      .from("attachments")
      .getPublicUrl(storagePath);

    // Save to DB
    const { data: record, error } = await supabase
      .from("attachments")
      .insert({
        trip_id: tripId,
        file_name: fileName,
        file_type: mimeType || "application/octet-stream",
        file_size: bytes.length,
        storage_path: storagePath,
        ...(linkedItem ? { linked_item: linkedItem } : {}),
        ...(category ? { category } : {}),
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(
      JSON.stringify({ ...record, url: urlData.publicUrl }),
      { status: 201, headers }
    );
  } catch (err: any) {
    console.error("upload-json error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
}
