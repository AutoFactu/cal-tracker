import { readFileSync } from "fs";

async function testGroqWhisper() {
  const apiKey = process.env.STT_API_KEY;
  const baseUrl = process.env.STT_BASE_URL || "https://api.groq.com/openai/v1";
  const model = process.env.STT_MODEL || "whisper-large-v3-turbo";

  console.log("=== Groq Whisper API Test ===");
  console.log("Base URL:", baseUrl);
  console.log("Model:", model);
  console.log("API Key prefix:", apiKey ? apiKey.substring(0, 10) + "..." : "NOT SET");
  console.log("API Key length:", apiKey?.length || 0);
  console.log();

  if (!apiKey) {
    console.error("ERROR: STT_API_KEY is not set. Make sure to run with: bun --env-file=.env scripts/test-groq-whisper.ts");
    process.exit(1);
  }

  // Try with a small fake audio file first to see the exact error
  console.log("Test 1: Sending fake audio file (expected to fail validation)...");
  try {
    const fakeAudio = Buffer.from([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20]);
    const form = new FormData();
    const blob = new Blob([fakeAudio], { type: "audio/m4a" });
    form.append("file", blob, "test.m4a");
    form.append("model", model);

    const res = await fetch(`${baseUrl}/audio/transcriptions`, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}` },
      body: form,
    });

    console.log("Status:", res.status);
    console.log("Status Text:", res.statusText);
    const body = await res.text();
    console.log("Response body:", body);
  } catch (err) {
    console.error("Request failed:", err);
  }

  console.log("\n=== Test Complete ===");
}

testGroqWhisper();
