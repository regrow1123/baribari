import { GoogleGenerativeAI } from '@google/generative-ai';
import { getSupabase } from './_lib/supabase';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const onRequest: PagesFunction = async (context) => {
  const { request, env } = context;

  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

  try {
    const { tripId, userMessage, assistantMessage } = await request.json() as any;
    if (!tripId) return new Response(JSON.stringify({ error: 'tripId required' }), { status: 400, headers: cors });

    const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

    const prompt = `다음 여행 대화를 보고 짧은 여행 제목을 만들어줘. 이모지 1개 포함, 10자 이내. 제목만 출력해.
사용자: ${userMessage}
AI: ${(assistantMessage || '').substring(0, 200)}`;

    const result = await model.generateContent(prompt);
    const title = result.response.text().trim();

    const supabase = getSupabase(env);
    await supabase.from('trips').update({ title }).eq('id', tripId);

    return new Response(JSON.stringify({ title }), { headers: cors });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
  }
};
