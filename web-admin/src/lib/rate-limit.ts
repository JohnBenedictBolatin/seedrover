import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

type RateLimitOptions = {
  namespace: string;
  limit: number;
  windowMs: number;
  identifierParts?: Array<string | null | undefined>;
};

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

type PersistentRateLimitRow = {
  key: string;
  count: number;
  reset_at: string;
};

export type RateLimitResult = {
  key: string;
  limited: boolean;
  limit: number;
  remaining: number;
  resetAt: number;
  retryAfterSeconds: number;
};

const globalForRateLimit = globalThis as typeof globalThis & {
  __seedroverRateLimitStore?: Map<string, RateLimitBucket>;
};

function getStore() {
  globalForRateLimit.__seedroverRateLimitStore ??= new Map();
  return globalForRateLimit.__seedroverRateLimitStore;
}

function cleanExpiredBuckets(store: Map<string, RateLimitBucket>, now: number) {
  if (store.size < 1000) {
    return;
  }

  for (const [key, bucket] of store.entries()) {
    if (bucket.resetAt <= now) {
      store.delete(key);
    }
  }
}

async function checkPersistentRateLimit({
  key,
  limit,
  now,
  windowMs,
}: {
  key: string;
  limit: number;
  now: number;
  windowMs: number;
}): Promise<RateLimitResult | null> {
  const supabase = createSupabaseAdminClient();

  if (!supabase) {
    return null;
  }

  const { data, error } = await supabase
    .from("rate_limit_buckets")
    .select("key, count, reset_at")
    .eq("key", key)
    .maybeSingle<PersistentRateLimitRow>();

  if (error) {
    return null;
  }

  const resetAt = data ? new Date(data.reset_at).getTime() : 0;

  if (!data || !Number.isFinite(resetAt) || resetAt <= now) {
    const nextResetAt = now + windowMs;

    const { error: upsertError } = await supabase
      .from("rate_limit_buckets")
      .upsert({
        key,
        count: 1,
        reset_at: new Date(nextResetAt).toISOString(),
      });

    if (upsertError) {
      return null;
    }

    return {
      key,
      limited: false,
      limit,
      remaining: Math.max(limit - 1, 0),
      resetAt: nextResetAt,
      retryAfterSeconds: Math.ceil(windowMs / 1000),
    };
  }

  if (data.count >= limit) {
    return {
      key,
      limited: true,
      limit,
      remaining: 0,
      resetAt,
      retryAfterSeconds: Math.max(1, Math.ceil((resetAt - now) / 1000)),
    };
  }

  const nextCount = data.count + 1;
  const { error: updateError } = await supabase
    .from("rate_limit_buckets")
    .update({ count: nextCount })
    .eq("key", key);

  if (updateError) {
    return null;
  }

  return {
    key,
    limited: false,
    limit,
    remaining: Math.max(limit - nextCount, 0),
    resetAt,
    retryAfterSeconds: Math.max(1, Math.ceil((resetAt - now) / 1000)),
  };
}

export async function checkRateLimit({
  identifierParts = [],
  limit,
  namespace,
  windowMs,
}: RateLimitOptions): Promise<RateLimitResult> {
  const headerStore = await headers();
  const forwardedFor = headerStore.get("x-forwarded-for")?.split(",")[0]?.trim();
  const realIp =
    headerStore.get("x-real-ip") ?? headerStore.get("cf-connecting-ip");
  const userAgent = headerStore.get("user-agent") ?? "unknown-agent";
  const ipAddress = forwardedFor || realIp || "unknown-ip";
  const extraIdentifier = identifierParts
    .map((part) => part?.trim())
    .filter(Boolean)
    .join(":");
  const fallbackIdentifier = userAgent.slice(0, 80);
  const key = `${namespace}:${ipAddress}:${extraIdentifier || fallbackIdentifier}`;
  const now = Date.now();

  const persistentResult = await checkPersistentRateLimit({
    key,
    limit,
    now,
    windowMs,
  });

  if (persistentResult) {
    return persistentResult;
  }

  const store = getStore();

  cleanExpiredBuckets(store, now);

  const existingBucket = store.get(key);

  if (!existingBucket || existingBucket.resetAt <= now) {
    const resetAt = now + windowMs;
    store.set(key, { count: 1, resetAt });

    return {
      key,
      limited: false,
      limit,
      remaining: Math.max(limit - 1, 0),
      resetAt,
      retryAfterSeconds: Math.ceil(windowMs / 1000),
    };
  }

  if (existingBucket.count >= limit) {
    return {
      key,
      limited: true,
      limit,
      remaining: 0,
      resetAt: existingBucket.resetAt,
      retryAfterSeconds: Math.max(
        1,
        Math.ceil((existingBucket.resetAt - now) / 1000),
      ),
    };
  }

  existingBucket.count += 1;

  return {
    key,
    limited: false,
    limit,
    remaining: Math.max(limit - existingBucket.count, 0),
    resetAt: existingBucket.resetAt,
    retryAfterSeconds: Math.max(
      1,
      Math.ceil((existingBucket.resetAt - now) / 1000),
    ),
  };
}

export function rateLimitHeaders(result: RateLimitResult) {
  const headers = new Headers({
    "X-RateLimit-Limit": String(result.limit),
    "X-RateLimit-Remaining": String(result.remaining),
    "X-RateLimit-Reset": String(Math.ceil(result.resetAt / 1000)),
  });

  if (result.limited) {
    headers.set("Retry-After", String(result.retryAfterSeconds));
  }

  return headers;
}

export function rateLimitResponse(message: string, result: RateLimitResult) {
  return NextResponse.json(
    { error: message },
    { headers: rateLimitHeaders(result), status: 429 },
  );
}

export async function checkExportRateLimit(request: Request) {
  const pathname = new URL(request.url).pathname;

  return checkRateLimit({
    identifierParts: [pathname],
    limit: 12,
    namespace: "exports",
    windowMs: 5 * 60 * 1000,
  });
}

export function formatRetryAfter(seconds: number) {
  if (seconds < 60) {
    return `${seconds} second${seconds === 1 ? "" : "s"}`;
  }

  const minutes = Math.ceil(seconds / 60);
  return `${minutes} minute${minutes === 1 ? "" : "s"}`;
}
