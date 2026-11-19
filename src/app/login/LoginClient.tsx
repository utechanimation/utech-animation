'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { ArrowRight } from 'lucide-react'
import { createClient } from '@/lib/supabase'
import { Stars } from '@/components/brand/Decor'
import Wordmark from '@/components/brand/Wordmark'

export default function LoginClient({ signInFailed = false }: { signInFailed?: boolean }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [isSignUp, setIsSignUp] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(
    signInFailed
      ? "We couldn't sign you in. Use your UTech student Microsoft account, or the email a lecturer invited."
      : ''
  )
  const [message, setMessage] = useState('')
  const [msLoading, setMsLoading] = useState(false)
  const router = useRouter()
  const [supabase] = useState(() => createClient())

  const signInWithMicrosoft = async () => {
    setMsLoading(true)
    setError('')
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'azure',
      options: {
        scopes: 'email',
        redirectTo: `${window.location.origin}/auth/callback?next=/dashboard`,
      },
    })
    if (error) {
      setError(error.message)
      setMsLoading(false)
    }
  }

  const handleAuth = async () => {
    setLoading(true)
    setError('')

    if (isSignUp) {
      const username = email.split('@')[0].toLowerCase().replace(/[^a-z0-9]/g, '')
      const { error } = await supabase.auth.signUp({
        email, password,
        options: {
          data: { full_name: fullName, username }
        }
      })
      if (error) setError(error.message)
      else setMessage('Check your email to confirm your account!')
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) setError(error.message)
      else router.push('/dashboard')
    }
    setLoading(false)
  }

  return (
    <div className="nebula flex min-h-[calc(100dvh-64px)] flex-col items-center px-6 pb-10 pt-10 md:justify-center">
      <Stars />
      <div className="flex w-full max-w-[380px] flex-col items-center gap-7">
        <Wordmark layout="stacked" withOwl />

        <div className="flex flex-col items-center gap-2 text-center">
          <h1 className="text-[34px] leading-[1.05]">
            Show the world<br />what you <span className="rainbow-text">make.</span>
          </h1>
          <p className="max-w-[300px] text-[15px] leading-relaxed text-soft">
            Post your portfolio, get a link, share it with studios, friends and family.
          </p>
        </div>

        <div className="flex w-full flex-col gap-3.5">
          <button
            type="button"
            onClick={signInWithMicrosoft}
            disabled={msLoading}
            className="btn h-14 rounded-2xl bg-white text-base text-[#1b1a1f] shadow-[0_10px_30px_rgba(147,51,234,.35)] hover:bg-[#f4f4f5]"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden>
              <rect x="0" y="0" width="9" height="9" fill="#F25022" />
              <rect x="11" y="0" width="9" height="9" fill="#7FBA00" />
              <rect x="0" y="11" width="9" height="9" fill="#00A4EF" />
              <rect x="11" y="11" width="9" height="9" fill="#FFB900" />
            </svg>
            {msLoading ? 'Opening Microsoft…' : 'Sign in with Microsoft'}
          </button>
          <p className="text-center text-[13px] leading-relaxed text-soft">
            Students: use your <strong className="text-ink">@students.utech.edu.jm</strong> account.
            <br />Lecturers: use the email your invite went to.
          </p>

          {error && <p role="alert" className="rounded-xl bg-[var(--danger-bg)] px-3 py-2 text-center text-[13px] text-[var(--danger-text)]">{error}</p>}
          {message && <p role="status" className="text-center text-[13px] text-mist">{message}</p>}

          <Link href="/" className="btn btn-ghost h-12 border-[rgba(233,213,255,.35)] text-mist">
            Browse without an account <ArrowRight size={18} aria-hidden />
          </Link>

          {/* TEMPORARY: email + password from the demo. Remove once Microsoft
              sign-in is set up in Supabase (see README → Sign-in). */}
          <details className="mt-2 rounded-2xl border border-line bg-[rgba(10,10,10,.6)] px-4 py-3 text-sm">
            <summary className="cursor-pointer select-none text-[13px] font-semibold text-muted">
              Demo sign-in with email (temporary)
            </summary>
            <div className="mt-4 flex flex-col gap-3">
              {isSignUp && (
                <div className="flex flex-col gap-1.5">
                  <label htmlFor="full-name" className="label">Full name</label>
                  <input id="full-name" className="field" value={fullName} onChange={e => setFullName(e.target.value)} />
                </div>
              )}
              <div className="flex flex-col gap-1.5">
                <label htmlFor="email" className="label">Email</label>
                <input id="email" className="field" type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} />
              </div>
              <div className="flex flex-col gap-1.5">
                <label htmlFor="password" className="label">Password</label>
                <input
                  id="password" className="field" type="password"
                  autoComplete={isSignUp ? 'new-password' : 'current-password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleAuth()}
                />
              </div>
              <button onClick={handleAuth} disabled={loading} className="btn btn-primary mt-1">
                {loading ? 'Please wait…' : isSignUp ? 'Create account' : 'Sign in'}
              </button>
              <button
                type="button"
                onClick={() => { setIsSignUp(!isSignUp); setError(''); setMessage('') }}
                className="min-h-[40px] text-[13px] text-muted underline underline-offset-4"
              >
                {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"}
              </button>
            </div>
          </details>
        </div>

        <nav aria-label="Policies" className="flex gap-5 text-xs text-mist">
          <Link href="/terms" className="underline underline-offset-4">Terms</Link>
        </nav>
      </div>
    </div>
  )
}
