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

    const body = await req.json();

    // Handle Disconnect & Purge
    if (body.action === 'disconnect') {
      // 1. Fetch current refresh token to attempt Google revoke
      const { data: cred } = await supabase
        .from('gmail_credentials')
        .select('refresh_token')
        .eq('user_id', user.id)
        .maybeSingle();

      if (cred?.refresh_token) {
        try {
          await fetch(`https://oauth2.googleapis.com/revoke?token=${cred.refresh_token}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          });
        } catch (revokeErr) {
          console.warn('Could not revoke Google token:', revokeErr);
        }
      }

      // 2. Delete all records associated with this user
      await supabase.from('gmail_credentials').delete().eq('user_id', user.id);
      await supabase.from('class_updates').delete().eq('user_id', user.id);
      await supabase.from('email_sources').delete().eq('user_id', user.id);
      await supabase.from('mail_settings').delete().eq('user_id', user.id);

      return new Response(JSON.stringify({ success: true, message: 'Disconnected and data purged' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const serverAuthCode = body.serverAuthCode;
    let refreshToken = body.refreshToken;
    let accessToken = body.accessToken;

    const clientId = Deno.env.get('GOOGLE_CLIENT_ID') || '';
    const clientSecret = Deno.env.get('GOOGLE_CLIENT_SECRET') || '';

    // If serverAuthCode is provided, exchange it for tokens
    if (serverAuthCode && clientId && clientSecret) {
      const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          code: serverAuthCode,
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: 'authorization_code',
          redirect_uri: '',
        }),
      });

      const tokenData = await tokenRes.json();
      if (tokenData.access_token) {
        accessToken = tokenData.access_token;
      }
      if (tokenData.refresh_token) {
        refreshToken = tokenData.refresh_token;
      }
    }

    // If we only have a refresh token but no access token, get fresh access token
    if (!accessToken && refreshToken && clientId && clientSecret) {
      const refreshRes = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          refresh_token: refreshToken,
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: 'refresh_token',
        }),
      });
      const refreshData = await refreshRes.json();
      accessToken = refreshData.access_token;
    }

    let googleEmail = user.email ?? '';
    let startingHistoryId: string | null = null;

    // Fetch Gmail profile to verify access and get starting historyId
    if (accessToken) {
      try {
        const profileRes = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/profile', {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (profileRes.ok) {
          const profileData = await profileRes.json();
          googleEmail = profileData.emailAddress || googleEmail;
          startingHistoryId = profileData.historyId ? String(profileData.historyId) : null;
        }
      } catch (err) {
        console.error('Failed to fetch Gmail profile:', err);
      }
    }

    // Save refresh token securely in gmail_credentials (service role only table)
    if (refreshToken) {
      await supabase.from('gmail_credentials').upsert({
        user_id: user.id,
        refresh_token: refreshToken,
        google_email: googleEmail,
        updated_at: new Date().toISOString(),
      });
    }

    // Initialize or update mail_settings
    await supabase.from('mail_settings').upsert({
      user_id: user.id,
      sync_enabled: true,
      gmail_history_id: startingHistoryId,
      last_synced_at: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        email: googleEmail,
        historyId: startingHistoryId,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
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
