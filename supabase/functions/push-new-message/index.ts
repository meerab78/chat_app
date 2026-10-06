import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically
// by Supabase to every Edge Function — no need to set them ourselves
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// This one we DO set ourselves (the Firebase service account JSON, as text)
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
const PROJECT_ID = serviceAccount.project_id;

// Exchanges the service account key for a short-lived FCM access token
async function getAccessToken(): Promise<string> {
  const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");
  const now = Math.floor(Date.now() / 1000);

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!data.access_token) {
    throw new Error("Failed to get FCM access token: " + JSON.stringify(data));
  }
  return data.access_token;
}

// Turns a message into the text shown in the notification
function bodyForMessage(messageType: string, content: string): string {
  if (messageType === "image") return "📷 Photo";
  if (messageType === "voice") return "🎤 Voice message";
  if (messageType === "file") return "📎 " + content;
  if (messageType === "location") return "📍 Location";
  return content;
}

Deno.serve(async (req) => {
  try {
    const { chat_id, message_id } = await req.json();
    if (!chat_id || !message_id) {
      return new Response(
        JSON.stringify({ error: "chat_id and message_id are required" }),
        { status: 400 },
      );
    }

    // Service role key = ignores RLS, so this function can read every
    // member's device token, not just the caller's own
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: message } = await supabase
      .from("messages")
      .select("sender_id, content, message_type")
      .eq("id", message_id)
      .single();

    if (!message) {
      return new Response(JSON.stringify({ error: "message not found" }), {
        status: 404,
      });
    }

    const { data: chat } = await supabase
      .from("chats")
      .select("name, is_group")
      .eq("id", chat_id)
      .single();

    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("name")
      .eq("id", message.sender_id)
      .single();

    const senderName = senderProfile?.name ?? "Someone";
    const title = chat?.is_group
      ? `${senderName} in ${chat?.name ?? "Group"}`
      : senderName;
    const body = bodyForMessage(message.message_type, message.content);

    // Everyone in the chat except the sender, and not someone who left
    const { data: members } = await supabase
      .from("chat_members")
      .select("user_id")
      .eq("chat_id", chat_id)
      .is("left_at", null)
      .neq("user_id", message.sender_id);

    const recipientIds = (members ?? []).map((m) => m.user_id);
    if (recipientIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .in("user_id", recipientIds);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const accessToken = await getAccessToken();

    // Send one push per device token. Data-only (no "notification" key)
    // so the Flutter side always builds its own local notification
    // and Reply / Mark-as-read actions keep working.
    const results = await Promise.allSettled(
      tokens.map((t) =>
        fetch(
          `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                data: {
                  title,
                  body,
                  chat_id,
                  chat_name: chat?.name ?? "",
                  sender_name: senderName,
                  is_group: chat?.is_group ? "true" : "false",
                  message_id,
                },
                android: { priority: "high" },
              },
            }),
          },
        ).then(async (r) => {
          if (!r.ok) {
            const errText = await r.text();
            // Token is no longer valid on Firebase's side -> clean it up
            if (errText.includes("UNREGISTERED") || errText.includes("NOT_FOUND")) {
              await supabase.from("device_tokens").delete().eq("token", t.token);
            }
            throw new Error(errText);
          }
          return r.json();
        }),
      ),
    );

    const sentCount = results.filter((r) => r.status === "fulfilled").length;
    return new Response(
      JSON.stringify({ sent: sentCount, total: tokens.length }),
      { status: 200 },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
    });
  }
});