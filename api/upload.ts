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
    const contentType = req.headers.get("content-type") || "";
    
    let tripId: string;
    let fileName: string;
    let mimeType: string;
    let fileSize: number;
    let fileBuffer: ArrayBuffer;
    let linkedItem: string | null = null;
    let category: string | null = null;

    if (contentType.includes("application/json")) {
      // JSON + base64 mode (from Flutter Web)
      const body = await req.json();
      tripId = body.tripId;
      fileName = body.fileName;
      mimeType = body.mimeType || "application/octet-stream";
      linkedItem = body.linkedItem || null;
      category = body.category || null;

      const binaryStr = atob(body.data);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }
      fileBuffer = bytes.buffer;
      fileSize = bytes.length;
    } else {
      // FormData mode (legacy)
      const formData = await req.formData();
      const file = formData.get("file") as File | null;
      tripId = formData.get("tripId") as string || "";
      linkedItem = formData.get("linkedItem") as string | null;
      category = formData.get("category") as string | null;

      if (!file) {
        return new Response(JSON.stringify({ error: "file required" }), { status: 400, headers });
      }
      fileName = file.name;
      mimeType = file.type;
      fileSize = file.size;
      fileBuffer = await file.arrayBuffer();
    }

    if (!tripId || !fileName) {
      return new Response(JSON.stringify({ error: "tripId and fileName required" }), { status: 400, headers });
    }

    // Upload to Supabase Storage
    const storagePath = `${tripId}/${Date.now()}_${fileName}`;
    const { error: uploadError } = await supabase.storage
      .from("attachments")
      .upload(storagePath, fileBuffer, {
        contentType: mimeType,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from("attachments")
      .getPublicUrl(storagePath);

    const { data, error } = await supabase
      .from("attachments")
      .insert({
        trip_id: tripId,
        file_name: fileName,
        file_type: mimeType,
        file_size: fileSize,
        storage_path: storagePath,
        ...(linkedItem ? { linked_item: linkedItem } : {}),
        ...(category ? { category } : {}),
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(
      JSON.stringify({ ...data, url: urlData.publicUrl }),
      { status: 201, headers }
    );
  } catch (err: any) {
    console.error("upload error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
}
