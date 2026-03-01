import { GoogleGenerativeAI } from "@google/generative-ai";
import { SYSTEM_PROMPT } from "./_lib/prompts.js";
import { supabase } from "./_lib/supabase.js";

export const config = {
  runtime: "edge",
};

export default async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders() });
  }

  try {
    const { message, history, tripId } = await req.json();

    if (!message || typeof message !== "string") {
      return new Response(JSON.stringify({ error: "message is required" }), {
        status: 400,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "API key not configured" }), {
        status: 500,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      systemInstruction: SYSTEM_PROMPT,
      generationConfig: {
        maxOutputTokens: 2048,
      },
    });

    // Build chat history
    const chatHistory = (history || []).map((msg: any) => ({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{ text: msg.content }],
    }));

    const chat = model.startChat({ history: chatHistory });

    // Save user message to DB
    if (tripId && process.env.SUPABASE_URL) {
      await supabase.from('messages').insert({
        trip_id: tripId,
        role: 'user',
        content: message,
        message_type: 'text',
      });
    }

    // Stream response
    const result = await chat.sendMessageStream(message);

    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        try {
          for await (const chunk of result.stream) {
            const text = chunk.text();
            if (text) {
              controller.enqueue(
                encoder.encode(`data: ${JSON.stringify({ type: "text", content: text })}\n\n`)
              );
            }
          }
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: "done" })}\n\n`));

          // Save assistant response to DB
          if (tripId && process.env.SUPABASE_URL) {
            const fullText = (await result.response).text();
            // Detect message type from content
            let messageType = 'text';
            let metadata = null;
            if (fullText.includes('```json:itinerary')) {
              messageType = 'itinerary_card';
              const match = fullText.match(/```json:itinerary\s*([\s\S]*?)```/);
              if (match) try { metadata = JSON.parse(match[1]); } catch {}
            } else if (fullText.includes('```json:packing')) {
              messageType = 'packing_card';
              const match = fullText.match(/```json:packing\s*([\s\S]*?)```/);
              if (match) try { metadata = JSON.parse(match[1]); } catch {}
            }
            await supabase.from('messages').insert({
              trip_id: tripId,
              role: 'assistant',
              content: fullText,
              message_type: messageType,
              metadata,
            });
          }

          controller.close();
        } catch (err: any) {
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({ type: "error", content: err.message })}\n\n`)
          );
          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        ...corsHeaders(),
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  } catch (err: any) {
    console.error("Chat API error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}
