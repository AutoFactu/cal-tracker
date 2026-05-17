import { AsyncLocalStorage } from "node:async_hooks";

export type ProfileSpan = {
  name: string;
  startedAtMs: number;
  durationMs?: number;
  metadata?: Record<string, unknown>;
  error?: string;
  children: ProfileSpan[];
};

export type ProfileSnapshot = {
  name: string;
  startedAt: string;
  durationMs?: number;
  metadata?: Record<string, unknown>;
  spans: ProfileSpan[];
};

type ProfileState = {
  root: ProfileSpan;
  stack: ProfileSpan[];
  startedAt: string;
};

const storage = new AsyncLocalStorage<ProfileState>();

export async function runWithProfile<T>(
  name: string,
  metadata: Record<string, unknown>,
  callback: () => Promise<T>,
): Promise<{ result: T; profile: ProfileSnapshot }> {
  const root: ProfileSpan = {
    name,
    startedAtMs: Date.now(),
    metadata,
    children: [],
  };
  const state: ProfileState = {
    root,
    stack: [root],
    startedAt: new Date(root.startedAtMs).toISOString(),
  };
  const result = await storage.run(state, callback);
  root.durationMs ??= Date.now() - root.startedAtMs;
  return { result, profile: snapshot(state) };
}

export async function withSpan<T>(
  name: string,
  metadata: Record<string, unknown> | undefined,
  callback: () => Promise<T>,
): Promise<T> {
  const state = storage.getStore();
  if (!state) return callback();
  const parent = state.stack[state.stack.length - 1] ?? state.root;
  const span: ProfileSpan = {
    name,
    startedAtMs: Date.now(),
    metadata,
    children: [],
  };
  parent.children.push(span);
  state.stack.push(span);
  try {
    const result = await callback();
    span.durationMs = Date.now() - span.startedAtMs;
    return result;
  } catch (error) {
    span.durationMs = Date.now() - span.startedAtMs;
    span.error = error instanceof Error ? error.message : String(error);
    throw error;
  } finally {
    state.stack.pop();
  }
}

export function withSyncSpan<T>(
  name: string,
  metadata: Record<string, unknown> | undefined,
  callback: () => T,
): T {
  const state = storage.getStore();
  if (!state) return callback();
  const parent = state.stack[state.stack.length - 1] ?? state.root;
  const span: ProfileSpan = {
    name,
    startedAtMs: Date.now(),
    metadata,
    children: [],
  };
  parent.children.push(span);
  state.stack.push(span);
  try {
    const result = callback();
    span.durationMs = Date.now() - span.startedAtMs;
    return result;
  } catch (error) {
    span.durationMs = Date.now() - span.startedAtMs;
    span.error = error instanceof Error ? error.message : String(error);
    throw error;
  } finally {
    state.stack.pop();
  }
}

export function activeProfileSnapshot(): ProfileSnapshot | undefined {
  const state = storage.getStore();
  return state ? snapshot(state) : undefined;
}

function snapshot(state: ProfileState): ProfileSnapshot {
  return {
    name: state.root.name,
    startedAt: state.startedAt,
    durationMs: state.root.durationMs ?? Date.now() - state.root.startedAtMs,
    metadata: state.root.metadata,
    spans: state.root.children,
  };
}
