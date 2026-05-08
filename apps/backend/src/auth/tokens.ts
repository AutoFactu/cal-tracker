import { createHash, randomBytes } from "node:crypto";
import { SignJWT, jwtVerify } from "jose";
import type { PermissionScope } from "@cal-tracker/contracts";
import type { AppConfig } from "../config/env.js";

export type AccessTokenClaims = {
  sub: string;
  scopes: PermissionScope[];
};

const encoder = new TextEncoder();

export async function signAccessToken(config: AppConfig, claims: AccessTokenClaims): Promise<{ token: string; expiresAt: string }> {
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const token = await new SignJWT({ scopes: claims.scopes })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.sub)
    .setIssuedAt()
    .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
    .sign(encoder.encode(config.JWT_ACCESS_SECRET));

  return { token, expiresAt: expiresAt.toISOString() };
}

export async function verifyAccessToken(config: AppConfig, token: string): Promise<AccessTokenClaims> {
  const { payload } = await jwtVerify(token, encoder.encode(config.JWT_ACCESS_SECRET));
  return {
    sub: payload.sub!,
    scopes: (payload.scopes as PermissionScope[]) ?? []
  };
}

export function createRefreshToken(): string {
  return randomBytes(48).toString("base64url");
}

export function hashRefreshToken(config: AppConfig, refreshToken: string): string {
  return createHash("sha256").update(`${config.SESSION_TOKEN_PEPPER}:${refreshToken}`).digest("hex");
}

export function refreshExpiry(): string {
  return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
}
