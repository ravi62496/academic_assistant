import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { user_id } = await req.json();

  // 1. Get stored refresh token, mint a fresh access token
  const { data: tokenRow } = await supabase
    .from('gmail_tokens')
    .select('refresh_token')
    .eq('user_id', user_id)
    .single();

  if (!tokenRow?.refresh_token) {
    return new Response(JSON.stringify({ error: 'No refresh token found for user' }), { status: 400 });
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
      client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
      refresh_token: tokenRow.refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  const tokenData = await tokenRes.json();
  const access_token = tokenData.access_token;

  if (!access_token) {
    return new Response(JSON.stringify({ error: 'Failed to refresh Google access token', details: tokenData }), { status: 400 });
  }

  // 2. Check user profile preference: read_all_emails
  const { data: profile } = await supabase
    .from('profiles')
    .select('read_all_emails')
    .eq('id', user_id)
    .maybeSingle();

  const readAll = profile?.read_all_emails ?? false;

  let gmailQuery = '';
  if (readAll) {
    // User allows scanning all mails for schedule/cancellation keywords
    gmailQuery = '(cancel OR postpone OR reschedule OR quiz OR class) newer_than:2d';
  } else {
    // Restrict strictly to user-specific allowed senders (Privacy Mode)
    const { data: filters } = await supabase
      .from('user_email_filters')
      .select('sender_email')
      .eq('user_id', user_id);

    const allowedSenders = filters?.map((f: any) => f.sender_email) ?? [];
    if (allowedSenders.length === 0) {
      allowedSenders.push('academics@iitmandi.ac.in'); // default fallback
    }
    const senderQuery = allowedSenders.map((s: string) => `from:${s}`).join(' OR ');
    gmailQuery = `(${senderQuery}) newer_than:2d`;
  }

  // 3. Query Gmail
  const gmailRes = await fetch(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(gmailQuery)}`,
    { headers: { Authorization: `Bearer ${access_token}` } },
  );
  const gmailData = await gmailRes.json();
  const messages = gmailData.messages;
  if (!messages?.length) return new Response(JSON.stringify({ processed: 0 }));

  let processed = 0;
  for (const m of messages) {
    // Skip if already processed
    const { data: existing } = await supabase
      .from('class_updates')
      .select('id')
      .eq('source_message_id', m.id)
      .maybeSingle();
    if (existing) continue;

    const msgRes = await fetch(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/${m.id}?format=full`,
      { headers: { Authorization: `Bearer ${access_token}` } },
    );
    const msg = await msgRes.json();
    const subject = msg.payload.headers.find((h: any) => h.name === 'Subject')?.value ?? '';
    const bodyText = extractBody(msg.payload);

    const parsed = await parseClassUpdate(subject, bodyText);
    if (!parsed) continue;

    await supabase.from('class_updates').insert({
      user_id,
      ...parsed,
      source_message_id: m.id,
    });
    processed++;
  }

  return new Response(JSON.stringify({ processed }));
});

// Helper to extract email body from MIME structure
function extractBody(payload: any): string {
  if (payload.body?.data) {
    return atob(payload.body.data.replace(/-/g, '+').replace(/_/g, '/'));
  }
  if (payload.parts) {
    for (const part of payload.parts) {
      if (part.mimeType === 'text/plain' && part.body?.data) {
        return atob(part.body.data.replace(/-/g, '+').replace(/_/g, '/'));
      }
      if (part.parts) {
        const nested = extractBody(part);
        if (nested) return nested;
      }
    }
  }
  return '';
}

// Heuristic parsing function
async function parseClassUpdate(subject: string, body: string) {
  const text = `${subject} ${body}`;
  const courseMatch = text.match(/\b([A-Z]{2,4}-?\d{3})\b/); // e.g. MA-311
  if (!courseMatch) return null;

  const action = /cancel/i.test(text)
    ? 'cancelled'
    : /postpon|resched/i.test(text)
      ? 'postponed'
      : null;
  if (!action) return null;

  return {
    course: courseMatch[1],
    event_type: /quiz/i.test(text) ? 'quiz' : 'class',
    action,
    message: subject,
  };
}
