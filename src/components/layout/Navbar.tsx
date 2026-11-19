'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import type { User } from '@supabase/supabase-js'
import { Compass, LayoutGrid, LogIn, Plus, Search, UserRound } from 'lucide-react'
import { createClient } from '@/lib/supabase'
import Avatar from '../ui/Avatar'
import Wordmark from '../brand/Wordmark'

type NavProfile = { full_name: string | null; avatar_url: string | null; username: string | null }

/**
 * Top bar on every screen size, plus a bottom tab bar on phones.
 * The tab bar is hidden on portfolio pages, which have their own
 * like / comment / share bar in the same spot.
 */
export default function Navbar() {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState<NavProfile | null>(null)
  const router = useRouter()
  const pathname = usePathname()
  const [supabase] = useState(() => createClient())

  useEffect(() => {
    const loadProfile = (id: string) =>
      supabase.from('profiles')
        .select('full_name, avatar_url, username')
        .eq('id', id)
        .single()
        .then(({ data }) => setProfile(data))

    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user)
      if (data.user) loadProfile(data.user.id)
    })

    const { data: listener } = supabase.auth.onAuthStateChange((_e, session) => {
      setUser(session?.user ?? null)
      if (session?.user) loadProfile(session.user.id)
      else setProfile(null)
    })
    return () => listener.subscription.unsubscribe()
  }, [supabase])

  const signOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
  }

  const profileHref = profile?.username ? `/profile/${profile.username}` : '/settings'
  const hideTabBar = pathname.startsWith('/portfolio/')

  return (
    <>
      <header className="fixed inset-x-0 top-0 z-50 border-b border-line bg-[rgba(10,10,10,.82)] backdrop-blur-md">
        <nav aria-label="Top" className="mx-auto flex h-16 max-w-[1200px] items-center justify-between gap-4 px-4 md:px-6">
          <Link href="/" aria-label="UTech's Animation — home">
            <Wordmark withOwl className="whitespace-nowrap text-[19px] md:text-[22px]" />
          </Link>

          <div className="flex items-center gap-2 md:gap-3">
            {user ? (
              <>
                <div className="hidden items-center gap-1 md:flex">
                  <TopLink href="/dashboard" active={pathname === '/dashboard'}>My work</TopLink>
                  <TopLink href="/settings" active={pathname === '/settings'}>Settings</TopLink>
                </div>
                <Link href="/upload" className="btn btn-primary hidden md:inline-flex">
                  <Plus size={18} aria-hidden /> New portfolio
                </Link>
                <Link href={profileHref} aria-label="Your profile" className="rounded-full">
                  <Avatar url={profile?.avatar_url} name={profile?.full_name} size={36} />
                </Link>
                <button onClick={signOut} className="btn btn-ghost btn-sm hidden md:inline-flex">
                  Sign out
                </button>
              </>
            ) : (
              <Link href="/login" className="btn btn-sm border-[rgba(250,250,250,.25)] bg-[rgba(250,250,250,.1)] text-ink hover:bg-[rgba(250,250,250,.18)]">
                Sign in
              </Link>
            )}
          </div>
        </nav>
      </header>

      {!hideTabBar && (
        <nav
          aria-label="Main"
          className="fixed inset-x-3 bottom-3 z-50 flex h-[68px] items-center justify-around rounded-[22px] border border-[rgba(233,213,255,.16)] bg-[rgba(20,20,20,.94)] shadow-[0_16px_40px_rgba(0,0,0,.6)] backdrop-blur-md md:hidden"
          style={{ marginBottom: 'env(safe-area-inset-bottom)' }}
        >
          <TabLink href="/" label="Explore" active={pathname === '/'} icon={<Compass size={22} aria-hidden />} />
          <TabLink href="/#search" label="Search" icon={<Search size={22} aria-hidden />} />
          {user ? (
            <>
              <Link
                href="/upload"
                aria-label="New portfolio"
                className="-mt-7 flex h-14 w-14 -rotate-[4deg] items-center justify-center rounded-[20px] bg-accent-hover text-white shadow-[0_10px_24px_rgba(147,51,234,.55)] transition-transform active:scale-95"
              >
                <Plus size={26} strokeWidth={2.5} aria-hidden />
              </Link>
              <TabLink href="/dashboard" label="My work" active={pathname === '/dashboard'} icon={<LayoutGrid size={22} aria-hidden />} />
              <TabLink href={profileHref} label="Profile" active={pathname.startsWith('/profile/') && pathname === profileHref} icon={<UserRound size={22} aria-hidden />} />
            </>
          ) : (
            <TabLink href="/login" label="Sign in" active={pathname === '/login'} icon={<LogIn size={22} aria-hidden />} />
          )}
        </nav>
      )}
    </>
  )
}

function TopLink({ href, active, children }: { href: string; active?: boolean; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      aria-current={active ? 'page' : undefined}
      className={`rounded-xl px-3 py-2 text-sm font-semibold transition-colors ${active ? 'text-accent' : 'text-muted hover:text-ink'}`}
    >
      {children}
    </Link>
  )
}

function TabLink({ href, label, icon, active }: { href: string; label: string; icon: React.ReactNode; active?: boolean }) {
  return (
    <Link
      href={href}
      aria-current={active ? 'page' : undefined}
      className={`flex h-[52px] w-16 flex-col items-center justify-center gap-[3px] text-[10px] font-bold ${active ? 'text-lilac' : 'text-muted'}`}
    >
      {icon}
      {label}
    </Link>
  )
}
