const ALLOWED_MIME_TYPES = [
  "audio/m4a",
  "audio/mp4",
  "audio/wav",
  "audio/webm",
  "audio/ogg",
  "audio/aac",
];

const EXT_TO_MIME: Record<string, string> = {
  m4a: "audio/m4a",
  mp4: "audio/mp4",
  wav: "audio/wav",
  webm: "audio/webm",
  ogg: "audio/ogg",
  aac: "audio/aac",
};

const MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024; // 25 MB

export type AudioValidationResult =
  | { ok: true; buffer: Buffer; mimeType: string; filename: string }
  | { ok: false; error: string; status: 400 | 413 | 415 };

function inferMimeType(filename: string, declaredType?: string): string | undefined {
  if (declaredType && ALLOWED_MIME_TYPES.includes(declaredType)) {
    return declaredType;
  }
  const ext = filename.split(".").pop()?.toLowerCase();
  if (ext && EXT_TO_MIME[ext]) {
    return EXT_TO_MIME[ext];
  }
  return declaredType;
}

export function validateAudioUpload(file: unknown): AudioValidationResult {
  if (!file || typeof file !== "object") {
    return { ok: false, error: "Missing audio file.", status: 400 };
  }

  const f = file as {
    name?: string;
    type?: string;
    size?: number;
    arrayBuffer?: () => Promise<ArrayBuffer>;
  };

  if (!f.name || typeof f.size !== "number" || typeof f.arrayBuffer !== "function") {
    return { ok: false, error: "Invalid audio file upload.", status: 400 };
  }

  const mimeType = inferMimeType(f.name, f.type);
  if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) {
    return {
      ok: false,
      error: `Unsupported audio format: ${f.type ?? "unknown"}. Allowed: ${ALLOWED_MIME_TYPES.join(", ")}.`,
      status: 415,
    };
  }

  if (f.size > MAX_FILE_SIZE_BYTES) {
    return {
      ok: false,
      error: `Audio file too large. Maximum size is ${MAX_FILE_SIZE_BYTES / 1024 / 1024} MB.`,
      status: 413,
    };
  }

  // Note: arrayBuffer() is async, so the caller must await it.
  // This function only does synchronous validation.
  return {
    ok: true,
    buffer: Buffer.alloc(0), // placeholder; caller must read the actual bytes
    mimeType,
    filename: f.name,
  };
}

export async function readAudioBuffer(file: unknown): Promise<Buffer> {
  const f = file as { arrayBuffer: () => Promise<ArrayBuffer> };
  const arrayBuffer = await f.arrayBuffer();
  return Buffer.from(arrayBuffer);
}
