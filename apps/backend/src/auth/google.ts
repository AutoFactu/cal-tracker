import { createRemoteJWKSet, jwtVerify } from "jose";
import type { AppConfig } from "../config/env.js";

export type GoogleIdentityClaims = {
  subject: string;
  email: string;
  displayName: string;
};

export interface GoogleTokenVerifier {
  verify(idToken: string): Promise<GoogleIdentityClaims>;
}

export class RemoteGoogleTokenVerifier implements GoogleTokenVerifier {
  private readonly jwks = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

  constructor(private readonly config: AppConfig) {}

  async verify(idToken: string): Promise<GoogleIdentityClaims> {
    const audiences = this.config.GOOGLE_OAUTH_CLIENT_IDS.split(",")
      .map((value) => value.trim())
      .filter(Boolean);
    if (audiences.length === 0) {
      throw new Error("google_oauth_not_configured");
    }

    const { payload } = await jwtVerify(idToken, this.jwks, {
      audience: audiences,
      issuer: ["https://accounts.google.com", "accounts.google.com"]
    });

    const email = typeof payload.email === "string" ? payload.email : undefined;
    const emailVerified = payload.email_verified === true || payload.email_verified === "true";
    if (!payload.sub || !email || !emailVerified) {
      throw new Error("invalid_google_token");
    }

    const name = typeof payload.name === "string" && payload.name.trim().length > 0
      ? payload.name.trim()
      : email.split("@")[0];

    return {
      subject: payload.sub,
      email,
      displayName: name
    };
  }
}
