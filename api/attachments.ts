import { supabase } from "./_lib/supabase.js";

export const config = { runtime: "edge" };

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const tripId = url.searchParams.get("tripId");

  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });

  if (!tripId) {
    return new Response(JSON.stringify({ error: "tripId required" }), { status: 400, headers });
  }

  const { data, error } = await supabase
    .from("attachments")
    .select("*")
    .eq("trip_id", tripId)
    .order("created_at", { ascending: true });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
  }

  // Add public URLs
  const withUrls = (data || []).map((att: any) => {
    const { data: urlData } = supabase.storage
      .from("attachments")
      .getPublicUrl(att.storage_path);
    return { ...att, url: urlData.publicUrl };
  });

  return new Response(JSON.stringify(withUrls), { headers });
}
