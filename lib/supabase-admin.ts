import { createClient } from '@supabase/supabase-js'

// Guard against this module ever being bundled into client code. The
// service-role key bypasses Row Level Security and must never reach the browser.
if (typeof window !== 'undefined') {
  throw new Error('lib/supabase-admin.ts must only be imported in server-side code.')
}

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    'Missing Supabase admin environment variables. Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local.',
  )
}

/**
 * Privileged, server-only Supabase client.
 *
 * Uses the service-role key, which BYPASSES Row Level Security — it can read
 * and write every table. Use it only in server-side code: cron route handlers
 * (Klaviyo / Outseta syncs, automation_logs) and Server Components that read
 * the synced data for the dashboard. NEVER import this from a Client Component
 * or expose the key with a NEXT_PUBLIC_ prefix.
 *
 * For browser-safe, RLS-governed access use `lib/supabase.ts` instead.
 */
export const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
})
