const fetch = require("node-fetch");
const { createClient } = require("@supabase/supabase-js");

// ---- CONFIG ----
const WABA_ID = ''; // WhatsApp Business Account ID
const ACCESS_TOKEN = ''; // permanent or system user token
const SUPABASE_URL = '';
const SUPABASE_KEY = ''; // use service role if inserting
// ----------------

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function fetchTemplates() {
  const url = `https://graph.facebook.com/v22.0/${WABA_ID}/message_templates?limit=200`;
  const resp = await fetch(url, {
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
    },
  });

  if (!resp.ok) {
    throw new Error(`WhatsApp API error: ${resp.status} ${await resp.text()}`);
  }
  const data = await resp.json();
  console.log('data', data);
  return data.data || [];
}

async function upsertTemplates(templates) {
  const rows = templates.map((t) => ({
    id: t.id,
    name: t.name,
    category: t.category,
    previous_category: t.previous_category ?? null,
    status: t.status ?? null,
    language: t.language,
    components: t.components,
  }));

  const { error } = await supabase.from("message_template").upsert(rows, {
    onConflict: "id",
  });

  if (error) throw error;
}

async function main() {
  try {
    const templates = await fetchTemplates();
    console.log(`Fetched ${templates.length} templates`);
    await upsertTemplates(templates);
    console.log("Upsert complete.");
  } catch (err) {
    console.error("Failed:", err);
    process.exit(1);
  }
}

main();

