import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing Supabase environment variables. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local.',
  )
}

/**
 * Supabase client keyed with the public anon key.
 *
 * Safe to import from both Server and Client Components — it only uses the
 * public URL and anon key, so it is subject to your Row Level Security
 * policies. For privileged, server-only work (cron jobs, admin tasks) create a
 * separate client with the service-role key and never expose it to the browser.
 */
export const supabase = createClient(supabaseUrl, supabaseAnonKey)
