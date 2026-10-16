export function localSupabaseHost(value: string): string;
export function localSupabaseConfig(env?: NodeJS.ProcessEnv): {
  url: string;
  anonKey: string;
  serviceRoleKey: string;
  hostname: string;
};
export function applyLocalSupabaseConfig(env?: NodeJS.ProcessEnv): {
  url: string;
  anonKey: string;
  serviceRoleKey: string;
  hostname: string;
};
