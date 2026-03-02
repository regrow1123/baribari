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
    const formData = await req.formData();
    const file = formData.get("file") as File | null;
    const tripId = formData.get("tripId") as string | null;
    const linkedItem = formData.get("linkedItem") as string | null;
    const messageId = formData.get("messageId") as string | null;

    if (!file || !tripId) {
      return new Response(JSON.stringify({ error: "file and tripId required" }), { status: 400, headers });
    }

    // Upload to Supabase Storage
    const ext = file.name.split(".").pop() || "bin";
    const storagePath = `${tripId}/${Date.now()}_${file.name}`;

    const arrayBuffer = await file.arrayBuffer();
    const { error: uploadError } = await supabase.storage
      .from("attachments")
      .upload(storagePath, arrayBuffer, {
        contentType: file.type,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    // Get public URL
    const { data: urlData } = supabase.storage
      .from("attachments")
      .getPublicUrl(storagePath);

    // Save to attachments table
    const { data, error } = await supabase
      .from("attachments")
      .insert({
        trip_id: tripId,
        ...(messageId ? { message_id: messageId } : {}),
        file_name: file.name,
        file_type: file.type,
        file_size: file.size,
        storage_path: storagePath,
        ...(linkedItem ? { linked_item: linkedItem } : {}),
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(
      JSON.stringify({
        ...data,
        url: urlData.publicUrl,
        linkedItem,
      }),
      { status: 201, headers }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
}
