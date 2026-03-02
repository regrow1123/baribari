import { GoogleGenerativeAI } from "@google/generative-ai";
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
    const { tripId, userMessage, assistantMessage } = await req.json();
    if (!tripId) return new Response(JSON.stringify({ error: "tripId required" }), { status: 400, headers });

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) return new Response(JSON.stringify({ error: "no api key" }), { status: 500, headers });

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const result = await model.generateContent(
      `다음 여행 대화를 보고, 짧고 매력적인 여행 제목을 만들어줘. 이모지 1개 포함. 15자 이내. 제목만 출력해.

사용자: ${userMessage}
어시스턴트: ${assistantMessage?.substring(0, 200) || ""}`
    );

    const title = result.response.text().trim();

    // Update DB
    if (process.env.SUPABASE_URL) {
      await supabase
        .from("trips")
        .update({ title, updated_at: new Date().toISOString() })
        .eq("id", tripId);
    }

    return new Response(JSON.stringify({ title }), { headers });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
}
