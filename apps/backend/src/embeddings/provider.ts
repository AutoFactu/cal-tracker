export type EmbeddingInput = {
  model: string;
  input: string[];
};

export type EmbeddingResult = {
  model: string;
  dimensions: number;
  data: Array<{ embedding: number[] }>;
};

export interface EmbeddingProvider {
  embed(input: string[]): Promise<EmbeddingResult>;
}

export class LocalBgeM3EmbeddingProvider implements EmbeddingProvider {
  constructor(
    private readonly baseUrl: string,
    private readonly model: string,
    private readonly dimensions: number
  ) {}

  async embed(input: string[]): Promise<EmbeddingResult> {
    const response = await fetch(`${this.baseUrl}/v1/embeddings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: this.model, input } satisfies EmbeddingInput),
    });
    if (!response.ok) {
      throw new Error(`Embedding provider failed: ${response.status} ${await response.text()}`);
    }

    const result = await response.json() as EmbeddingResult;
    if (result.model !== this.model) {
      throw new Error(`Embedding model mismatch: expected ${this.model}, got ${result.model}`);
    }
    if (result.dimensions !== this.dimensions) {
      throw new Error(`Embedding dimensions mismatch: expected ${this.dimensions}, got ${result.dimensions}`);
    }
    for (const item of result.data) {
      if (item.embedding.length !== this.dimensions) {
        throw new Error(`Embedding vector length mismatch: expected ${this.dimensions}, got ${item.embedding.length}`);
      }
    }
    return result;
  }
}

export class UnavailableEmbeddingProvider implements EmbeddingProvider {
  async embed(): Promise<EmbeddingResult> {
    throw new Error("embedding_provider_unavailable");
  }
}
