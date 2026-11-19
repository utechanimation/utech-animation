import { createServerSupabaseClient } from '@/lib/supabase-server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import DashboardClient from '@/components/ui/DashboardClient'
import EmptyState from '@/components/brand/EmptyState'
import SignOutButton from '@/components/ui/SignOutButton'
import { Plus, ShieldCheck } from 'lucide-react'

export default async function Dashboard() {
  const supabase = await createServerSupabaseClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  // Check if admin
  const { data: adminRole } = await supabase
    .from('admin_roles')
    .select('user_id')
    .eq('user_id', user.id)
    .single()
  const isAdmin = !!adminRole

  const { data: portfolios } = await supabase
    .from('portfolios')
    .select(`*, portfolio_tags (tags (name)), takedowns(id, reason, appeal_status, appeal_message)`)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  const firstName = profile?.full_name?.trim().split(/\s+/)[0] ?? 'there'
  const stats = [
    { label: 'Public', value: portfolios?.filter(p => p.visibility === 'public' && p.status === 'active').length ?? 0 },
    { label: 'Unlisted', value: portfolios?.filter(p => p.visibility === 'unlisted').length ?? 0 },
    { label: 'Private', value: portfolios?.filter(p => p.visibility === 'private').length ?? 0 },
    { label: 'Need attention', value: portfolios?.filter(p => ['taken_down', 'pending_appeal', 'denied_appeal'].includes(p.status)).length ?? 0 },
  ]

  return (
    <div
      className="mx-auto max-w-[900px] px-4 pb-16 pt-6 md:px-6 md:pt-12"
      style={{ background: 'radial-gradient(70% 240px at 0% 0%, rgba(168,85,247,.18), transparent 70%)' }}
    >
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow">My work</p>
          <h1 className="text-[34px] md:text-5xl">Hey, {firstName}</h1>
        </div>
        <div className="flex gap-2.5">
          {isAdmin && (
            <Link href="/admin" className="btn btn-ghost">
              <ShieldCheck size={18} aria-hidden /> Admin
            </Link>
          )}
          <SignOutButton className="md:hidden" />
          <Link href="/upload" className="btn btn-primary hidden md:inline-flex">
            <Plus size={18} aria-hidden /> New portfolio
          </Link>
        </div>
      </div>

      {portfolios && portfolios.length > 0 && (
        <dl className="mb-8 grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {stats.map(stat => (
            <div key={stat.label} className="card flex flex-col-reverse px-4 py-3">
              <dt className="text-xs text-muted">{stat.label}</dt>
              <dd className="font-display text-[28px] font-extrabold leading-none">{stat.value}</dd>
            </div>
          ))}
        </dl>
      )}

      <h2 className="mb-4 text-2xl">Your portfolios</h2>
      {portfolios && portfolios.length > 0 ? (
        <DashboardClient portfolios={portfolios} />
      ) : (
        <EmptyState
          title="No portfolios yet"
          action={<Link href="/upload" className="btn btn-primary"><Plus size={18} aria-hidden /> Create your first portfolio</Link>}
        >
          Post your work and you&apos;ll get a link you can share anywhere.
        </EmptyState>
      )}
    </div>
  )
}
