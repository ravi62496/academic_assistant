import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify calling user from auth token
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid user session' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1. Fetch user's stored refresh token
    const { data: creds } = await supabase
      .from('gmail_credentials')
      .select('refresh_token')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!creds?.refresh_token) {
      return new Response(JSON.stringify({ error: 'Gmail not connected for this user' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Exchange refresh token for fresh access token
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: Deno.env.get('GOOGLE_CLIENT_ID') || '',
        client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET') || '',
        refresh_token: creds.refresh_token,
        grant_type: 'refresh_token',
      }),
    });
    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token;

    if (!accessToken) {
      return new Response(JSON.stringify({ error: 'Failed to obtain Gmail access token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Search messages from the last 30 days
    const searchRes = await fetch(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages?q=newer_than:30d&maxResults=100',
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    const searchData = await searchRes.json();
    const messageIds: string[] = (searchData.messages || []).map((m: any) => m.id);

    // Grouping by sender address
    const senderMap = new Map<string, { name: string; email: string; count: number; score: number }>();

    // Batch fetch metadata for headers
    const BATCH_SIZE = 10;
    for (let i = 0; i < messageIds.length; i += BATCH_SIZE) {
      const batch = messageIds.slice(i, i + BATCH_SIZE);
      await Promise.all(
        batch.map(async (id) => {
          try {
            const msgRes = await fetch(
              `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}?format=metadata&metadataHeaders=From&metadataHeaders=Subject`,
              { headers: { Authorization: `Bearer ${accessToken}` } },
            );
            if (!msgRes.ok) return;
            const msg = await msgRes.json();
            const headers = msg.payload?.headers || [];

            const fromHeader = headers.find((h: any) => h.name.toLowerCase() === 'from')?.value || '';
            const subjectHeader = headers.find((h: any) => h.name.toLowerCase() === 'subject')?.value || '';

            // Parse "Prof. John Doe <johndoe@institute.ac.in>"
            const emailMatch = fromHeader.match(/<([^>]+)>/) || fromHeader.match(/([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/);
            if (!emailMatch) return;

            const email = emailMatch[1].toLowerCase().trim();
            let name = fromHeader.replace(/<[^>]+>/, '').replace(/["']/g, '').trim();
            if (!name) name = email.split('@')[0];

            // Calculate academic score
            let emailScore = 0;

            // 1. Academic domain (.edu, .ac.in, etc.)
            if (/\.(edu|ac\.in|edu\.in)$/i.test(email.split('@')[1] || '')) {
              emailScore += 30;
            }

            // 2. Title indicators (Prof, Dr, Faculty, Instructor)
            if (/\b(prof|professor|dr|instructor|faculty)\b/i.test(name)) {
              emailScore += 40;
            }

            // 3. Subject containing course or academic keywords
            if (/\b(quiz|exam|midsem|endsem|assignment|lecture|class|tutorial|lab|deadline|submission)\b/i.test(subjectHeader)) {
              emailScore += 25;
            }

            // 4. Subject containing course code like CS101, MA201
            if (/\b[a-zA-Z]{2,4}\s?-?\d{3,4}\b/.test(subjectHeader)) {
              emailScore += 25;
            }

            const existing = senderMap.get(email);
            if (existing) {
              existing.count += 1;
              existing.score += emailScore;
              if (name && (!existing.name || existing.name === email.split('@')[0])) {
                existing.name = name;
              }
            } else {
              senderMap.set(email, {
                name,
                email,
                count: 1,
                score: emailScore,
              });
            }
          } catch (_) {
            // ignore individual message failures
          }
        }),
      );
    }

    // Convert map to list and sort
    const discovered = Array.from(senderMap.values()).map((s) => ({
      email: s.email,
      name: s.name,
      count: s.count,
      score: s.score,
      isLikelyProfessor: s.score >= 40 || /\b(prof|dr)\b/i.test(s.name),
    }));

    // Sort by likelihood of being an instructor
    discovered.sort((a, b) => b.score - a.score);

    return new Response(JSON.stringify({ senders: discovered }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
