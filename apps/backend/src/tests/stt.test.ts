import { describe, expect, it } from "vitest";
import { buildTestApp, registerAndAuth } from "./testApp.js";

describe("STT endpoint", () => {
  it("rejects unauthenticated requests", async () => {
    const { request } = buildTestApp();
    const res = await request("http://localhost/v1/stt/transcriptions", { method: "POST" });
    expect(res.status).toBe(401);
  });

  it("rejects missing audio", async () => {
    const { request } = buildTestApp();
    const { authHeader } = await registerAndAuth(request);
    const body = new FormData();
    const res = await request("http://localhost/v1/stt/transcriptions", {
      method: "POST",
      headers: bearerOnly(authHeader),
      body
    });
    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json.error.message).toContain("Missing audio file");
  });

  it("rejects unsupported mime type", async () => {
    const { request } = buildTestApp();
    const { authHeader } = await registerAndAuth(request);

    const body = new FormData();
    body.append("audio", new Blob(["fake audio"], { type: "audio/mp3" }), "test.mp3");

    const res = await request("http://localhost/v1/stt/transcriptions", {
      method: "POST",
      headers: bearerOnly(authHeader),
      body
    });
    expect(res.status).toBe(415);
    const json = await res.json();
    expect(json.error.message).toContain("Unsupported audio format");
  });

  it("returns fake transcript with test provider", async () => {
    const { request } = buildTestApp();
    const { authHeader } = await registerAndAuth(request);

    const body = new FormData();
    body.append("audio", new Blob(["fake audio"], { type: "audio/m4a" }), "test.m4a");

    const res = await request("http://localhost/v1/stt/transcriptions", {
      method: "POST",
      headers: bearerOnly(authHeader),
      body
    });
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.transcript).toBe("fake transcript from test");
    expect(json.provider).toBe("test");
    expect(json.model).toBe("test-model");
    expect(json.traceId).toBeDefined();
  });
});

function bearerOnly(authHeader: Record<string, string>): Record<string, string> {
  return { authorization: authHeader.authorization };
}
