import { supabase } from "./_lib/supabase.js";

export const config = { runtime: "edge" };

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const tripId = url.searchParams.get("tripId");
  const expenseId = url.searchParams.get("id");

  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });

  if (!tripId) {
    return new Response(JSON.stringify({ error: "tripId required" }), { status: 400, headers });
  }

  try {
    if (req.method === "GET") {
      const { data, error } = await supabase
        .from("expenses")
        .select("*")
        .eq("trip_id", tripId)
        .order("spent_at", { ascending: false });
      if (error) throw error;
      return new Response(JSON.stringify(data), { headers });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { data, error } = await supabase
        .from("expenses")
        .insert({
          trip_id: tripId,
          amount: body.amount,
          currency: body.currency || "KRW",
          category: body.category,
          memo: body.memo,
          day_number: body.dayNumber || null,
          linked_item: body.linkedItem || null,
          spent_at: body.spentAt || new Date().toISOString(),
        })
        .select()
        .single();
      if (error) throw error;
      return new Response(JSON.stringify(data), { status: 201, headers });
    }

    if (req.method === "DELETE" && expenseId) {
      const { error } = await supabase.from("expenses").delete().eq("id", expenseId);
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true }), { headers });
    }

    return new Response("Method not allowed", { status: 405, headers });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
}
