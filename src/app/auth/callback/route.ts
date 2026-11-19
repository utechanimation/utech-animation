import { NextResponse } from 'next/server'
import { createServerSupabaseClient } from '@/lib/supabase-server'

/**
 * Microsoft sign-in comes back here with a one-time `code`. We swap it for a
 * session cookie, then send the person on to `next` (default: /dashboard).
 *
 * `next` is only followed when it is a path on this site ("/something"),
 * so this route can't be used to bounce people to another website.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const nextParam = searchParams.get('next') ?? '/dashboard'
  const next = nextParam.startsWith('/') && !nextParam.startsWith('//') ? nextParam : '/dashboard'

  if (code) {
    const supabase = await createServerSupabaseClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}${next}`)
  }

  // Covers a refused account (e.g. not a @students.utech.edu.jm email) too.
  return NextResponse.redirect(`${origin}/login?error=signin`)
}
