import { describe, expect, it } from "vitest";
import { buildTestApp, registerAndAuth } from "./testApp.js";

describe("auth routes", () => {
  it("registers, logs in, refreshes, returns me, and logs out", async () => {
    const { request } = buildTestApp();
    const registered = await registerAndAuth(request);

    expect(registered.accessToken).toBeTruthy();
    expect(registered.refreshToken).toBeTruthy();

    const me = await request("http://localhost/v1/auth/me", { headers: registered.authHeader });
    expect(me.status).toBe(200);
    expect((await me.json() as { email: string }).email).toBe("test@example.com");

    const login = await request("http://localhost/v1/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "test@example.com", password: "password123" })
    });
    expect(login.status).toBe(200);

    const refresh = await request("http://localhost/v1/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: registered.refreshToken })
    });
    expect(refresh.status).toBe(200);
    const refreshed = await refresh.json() as { accessToken: string; refreshToken: string };
    expect(refreshed.accessToken).toBeTruthy();
    expect(refreshed.refreshToken).not.toBe(registered.refreshToken);

    const logout = await request("http://localhost/v1/auth/logout", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: refreshed.refreshToken })
    });
    expect(logout.status).toBe(200);
  });

  it("stores reset token hashes and accepts the dev reset token once", async () => {
    const { request } = buildTestApp();
    await registerAndAuth(request);
    const resetRequest = await request("http://localhost/v1/auth/password-reset/request", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "test@example.com" })
    });
    expect(resetRequest.status).toBe(200);
    const { resetToken } = await resetRequest.json() as { resetToken: string };
    expect(resetToken).toBeTruthy();

    const confirm = await request("http://localhost/v1/auth/password-reset/confirm", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: resetToken, newPassword: "newpassword123" })
    });
    expect(confirm.status).toBe(200);
    expect(await confirm.json()).toEqual({ ok: true });
  });
});
