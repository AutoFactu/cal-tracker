export type TranscriptionResult = {
  text: string;
  language?: string;
  durationSeconds?: number;
  provider: string;
  model: string;
};

export interface SpeechToTextProvider {
  transcribe(input: {
    audio: Buffer;
    filename: string;
    mimeType: string;
    userId: string;
    traceId: string;
  }): Promise<TranscriptionResult>;
}

export class RemoteSpeechToTextProvider implements SpeechToTextProvider {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly baseUrl: string
  ) {}

  async transcribe(input: {
    audio: Buffer;
    filename: string;
    mimeType: string;
    userId: string;
    traceId: string;
  }): Promise<TranscriptionResult> {
    const form = new FormData();
    const arrayBuffer = input.audio.buffer.slice(
      input.audio.byteOffset,
      input.audio.byteOffset + input.audio.byteLength
    ) as ArrayBuffer;
    const blob = new Blob([arrayBuffer], { type: input.mimeType });
    form.append("file", blob, input.filename);
    form.append("model", this.model);

    const res = await fetch(`${this.baseUrl}/audio/transcriptions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: form,
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`STT failed: ${res.status} ${err}`);
    }

    const json = (await res.json()) as { text: string };
    return {
      text: json.text,
      provider: "groq",
      model: this.model,
    };
  }
}
