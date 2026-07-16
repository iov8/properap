const PROJECT_HOST_SUFFIX = ".supabase.co";

export function getPublicSupabaseConfig() {
  const urlValue = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!urlValue || !publishableKey) {
    throw new Error("Supabase public environment variables are not configured.");
  }

  let url: URL;
  try {
    url = new URL(urlValue);
  } catch {
    throw new Error("The configured Supabase URL is invalid.");
  }

  if (url.protocol !== "https:" || !url.hostname.endsWith(PROJECT_HOST_SUFFIX)) {
    throw new Error("The configured Supabase URL is not an approved project URL.");
  }

  if (!publishableKey.startsWith("sb_publishable_")) {
    throw new Error("The configured Supabase key is not a publishable key.");
  }

  return { url: url.origin, publishableKey } as const;
}
