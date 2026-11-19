'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { AlertTriangle, CheckCircle2, ExternalLink, Globe, Hourglass, ImageOff, Link2, Lock, Pencil, Trash2, XCircle } from 'lucide-react'
import { createClient } from '@/lib/supabase'

const VISIBILITY_OPTIONS = [
  { value: 'public', label: 'Public', Icon: Globe },
  { value: 'unlisted', label: 'Unlisted (link only)', Icon: Link2 },
  { value: 'private', label: 'Private', Icon: Lock },
]

// Plain-word status labels. Normal states use purple shades; moderation
// states use the warning/danger colours from globals.css.
const STATUS_CONFIG: Record<string, { label: string; className: string; style?: React.CSSProperties }> = {
  active:         { label: 'Live',          className: 'bg-mist text-[#1a0530]' },
  reported:       { label: 'Reported',      className: '', style: { background: 'var(--warn-bg)', color: 'var(--warn-text)' } },
  taken_down:     { label: 'Taken down',    className: '', style: { background: 'var(--danger-bg)', color: 'var(--danger-text)' } },
  pending_appeal: { label: 'Appeal in review', className: 'bg-grape text-white' },
  denied_appeal:  { label: 'Appeal denied', className: '', style: { background: 'var(--danger-bg)', color: 'var(--danger-text)' } },
}

export default function DashboardClient({ portfolios }: { portfolios: any[] }) {
  const [list, setList] = useState(portfolios)
  const [deleting, setDeleting] = useState<string | null>(null)
  const [appealText, setAppealText] = useState<Record<string, string>>({})
  const [appealingId, setAppealingId] = useState<string | null>(null)
  const router = useRouter()
  const [supabase] = useState(() => createClient())

  const setVisibility = async (id: string, visibility: string) => {
    await supabase.from('portfolios').update({ visibility }).eq('id', id)
    setList(list.map(p => p.id === id ? { ...p, visibility } : p))
  }

  const deletePortfolio = async (id: string) => {
    if (!confirm('Delete this portfolio? This cannot be undone.')) return
    setDeleting(id)
    await supabase.from('portfolios').delete().eq('id', id)
    setList(list.filter(p => p.id !== id))
    setDeleting(null)
    router.refresh()
  }

  const submitAppeal = async (portfolioId: string, takedownId: string) => {
    const message = appealText[portfolioId]?.trim()
    if (!message) return
    setAppealingId(portfolioId)

    await supabase
      .from('takedowns')
      .update({ appeal_message: message, appeal_status: 'pending' })
      .eq('id', takedownId)

    await supabase
      .from('portfolios')
      .update({ status: 'pending_appeal' })
      .eq('id', portfolioId)

    setList(list.map(p => p.id === portfolioId ? {
      ...p,
      status: 'pending_appeal',
      takedowns: p.takedowns.map((t: any) =>
        t.id === takedownId
          ? { ...t, appeal_message: message, appeal_status: 'pending' }
          : t
      )
    } : p))
    setAppealingId(null)
  }

  const [counterText, setCounterText] = useState<Record<string, string>>({})

  const submitCounter = async (warningId: string) => {
  const statement = counterText[warningId]?.trim()
  if (!statement) return

  await supabase.from('warnings').update({
      counter_statement: statement,
      counter_submitted_at: new Date().toISOString()
  }).eq('id', warningId)

  setList(list.map(p => ({
      ...p,
      warnings: p.warnings?.map((w: any) =>
      w.id === warningId
          ? { ...w, counter_statement: statement, counter_submitted_at: new Date().toISOString() }
          : w
      )
  })))
  setCounterText(prev => ({ ...prev, [warningId]: '' }))
  }

  return (
    <div className="flex flex-col gap-3">
      {list.map(portfolio => {
        const tags = portfolio.portfolio_tags?.map((pt: any) => pt.tags.name) ?? []
        const takedown = portfolio.takedowns?.[0] ?? null
        const warnings = portfolio.warnings ?? []
        const activeWarning = warnings.find((w: any) => new Date(w.expires_at) > new Date())
        const status = portfolio.status ?? 'active'
        const statusConfig = STATUS_CONFIG[status] ?? STATUS_CONFIG.active
        const visConfig = VISIBILITY_OPTIONS.find(v => v.value === portfolio.visibility) ?? VISIBILITY_OPTIONS[0]
        const isLocked = ['taken_down', 'pending_appeal', 'denied_appeal'].includes(status)
        const canAppeal = status === 'taken_down' && takedown?.appeal_status === 'none'
        const appealPending = status === 'pending_appeal' || takedown?.appeal_status === 'pending'
        const appealDenied = status === 'denied_appeal' || takedown?.appeal_status === 'denied'

        const wipeDate = takedown?.scheduled_wipe_at
          ? new Date(takedown.scheduled_wipe_at).toLocaleDateString('en-JM', { year: 'numeric', month: 'long', day: 'numeric' })
          : null

        return (
          <div
            key={portfolio.id}
            className="overflow-hidden rounded-[18px] border bg-surface"
            style={{ borderColor: isLocked ? 'var(--danger-border)' : 'var(--border)' }}
          >
            {/* Warning banner */}
            {activeWarning && (
              <Banner tone="warn" icon={<AlertTriangle size={18} aria-hidden />} title="Warning from a moderator">
                <p>Reason: {activeWarning.reason}</p>
                <p className="opacity-80">
                  Ends {new Date(activeWarning.expires_at).toLocaleDateString('en-JM', { month: 'long', day: 'numeric', year: 'numeric' })}.
                  Your portfolio stays public until then.
                </p>
                {!activeWarning.counter_statement ? (
                  <div className="mt-3 flex flex-col gap-2">
                    <label htmlFor={`counter-${activeWarning.id}`} className="text-xs">
                      Tell the moderator what you&apos;ve changed (optional).
                    </label>
                    <textarea
                      id={`counter-${activeWarning.id}`}
                      placeholder="I've reviewed the warning and…"
                      value={counterText[activeWarning.id] ?? ''}
                      onChange={e => setCounterText(prev => ({ ...prev, [activeWarning.id]: e.target.value }))}
                      className="field min-h-[72px] border-[var(--warn-border)] bg-[rgba(0,0,0,.3)] text-[13px]"
                    />
                    <button
                      onClick={() => submitCounter(activeWarning.id)}
                      disabled={!counterText[activeWarning.id]?.trim()}
                      className="btn btn-sm self-start bg-[var(--warn-border)] text-[var(--warn-text)]"
                    >
                      Send reply
                    </button>
                  </div>
                ) : (
                  <p className="mt-2 flex items-start gap-2 rounded-lg bg-[rgba(0,0,0,.25)] px-3 py-2 italic">
                    <CheckCircle2 size={16} className="mt-0.5 shrink-0 not-italic" aria-hidden />
                    &ldquo;{activeWarning.counter_statement}&rdquo;
                  </p>
                )}
              </Banner>
            )}

            {/* Taken down banner */}
            {status === 'taken_down' && takedown && (
              <Banner tone="danger" icon={<XCircle size={18} aria-hidden />} title="Taken down by a moderator">
                <p>Reason: {takedown.reason}</p>
                {canAppeal && (
                  <div className="mt-3 flex flex-col gap-2">
                    <label htmlFor={`appeal-${portfolio.id}`} className="text-xs">
                      You can send one appeal. The decision after review is final.
                    </label>
                    <textarea
                      id={`appeal-${portfolio.id}`}
                      placeholder="Write your appeal…"
                      value={appealText[portfolio.id] ?? ''}
                      onChange={e => setAppealText(prev => ({ ...prev, [portfolio.id]: e.target.value }))}
                      className="field min-h-[80px] border-[var(--danger-border)] bg-[rgba(0,0,0,.3)] text-[13px]"
                    />
                    <button
                      onClick={() => submitAppeal(portfolio.id, takedown.id)}
                      disabled={appealingId === portfolio.id || !appealText[portfolio.id]?.trim()}
                      className="btn btn-sm self-start bg-[var(--danger-border)] text-white"
                    >
                      {appealingId === portfolio.id ? 'Sending…' : 'Send appeal'}
                    </button>
                  </div>
                )}
              </Banner>
            )}

            {/* Pending appeal banner */}
            {appealPending && (
              <Banner tone="info" icon={<Hourglass size={18} aria-hidden />} title="Appeal in review">
                <p>A moderator will look at your appeal.</p>
                {takedown?.appeal_message && <p className="mt-1 italic opacity-80">Your appeal: &ldquo;{takedown.appeal_message}&rdquo;</p>}
              </Banner>
            )}

            {/* Denied appeal banner */}
            {appealDenied && (
              <Banner tone="danger" icon={<XCircle size={18} aria-hidden />} title="Appeal denied — the decision is final">
                <p>Takedown reason: {takedown?.reason}</p>
                {takedown?.appeal_message && <p className="mt-1 italic opacity-80">Your appeal: &ldquo;{takedown.appeal_message}&rdquo;</p>}
                {wipeDate && <p className="mt-2 font-bold">This portfolio and its files will be permanently deleted on {wipeDate}.</p>}
              </Banner>
            )}

            <div className="flex flex-wrap items-center gap-4 p-3 md:p-4">
              <div className="h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-surface-2 md:h-[72px] md:w-[72px]">
                {portfolio.cover_image_url ? (
                  <img src={portfolio.cover_image_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full w-full items-center justify-center text-muted"><ImageOff size={20} aria-hidden /></div>
                )}
              </div>

              <div className="min-w-0 flex-1">
                <h3 className="truncate font-sans text-[15px] font-bold">{portfolio.title}</h3>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <span className={`badge ${statusConfig.className}`} style={statusConfig.style}>{statusConfig.label}</span>
                  <span className="badge border border-line text-soft">
                    <visConfig.Icon size={12} aria-hidden /> {visConfig.label}
                  </span>
                  {tags.map((tag: string) => (
                    <span key={tag} className="badge bg-surface-2 font-semibold text-muted">{tag}</span>
                  ))}
                </div>
              </div>

              <div className="flex w-full flex-wrap gap-2 md:w-auto">
                <Link href={`/portfolio/${portfolio.slug}`} target="_blank" className="btn btn-soft btn-sm">
                  View <ExternalLink size={14} aria-hidden />
                </Link>
                {status === 'active' && (
                  <>
                    <Link href={`/edit/${portfolio.id}`} className="btn btn-soft btn-sm">
                      <Pencil size={14} aria-hidden /> Edit
                    </Link>
                    <label className="sr-only" htmlFor={`vis-${portfolio.id}`}>Who can see {portfolio.title}</label>
                    <select
                      id={`vis-${portfolio.id}`}
                      value={portfolio.visibility}
                      onChange={e => setVisibility(portfolio.id, e.target.value)}
                      className="field !min-h-[36px] !w-auto !rounded-[11px] !py-0 text-[13px] font-semibold"
                    >
                      {VISIBILITY_OPTIONS.map(opt => (
                        <option key={opt.value} value={opt.value}>{opt.label}</option>
                      ))}
                    </select>
                  </>
                )}
                {!['pending_appeal', 'denied_appeal'].includes(status) && (
                  <button
                    onClick={() => deletePortfolio(portfolio.id)}
                    disabled={deleting === portfolio.id}
                    aria-label={`Delete ${portfolio.title}`}
                    className="btn btn-danger btn-sm md:ml-auto"
                  >
                    <Trash2 size={14} aria-hidden /> {deleting === portfolio.id ? 'Deleting…' : 'Delete'}
                  </button>
                )}
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

function Banner({ tone, icon, title, children }: {
  tone: 'warn' | 'danger' | 'info'
  icon: React.ReactNode
  title: string
  children: React.ReactNode
}) {
  const colours = {
    warn: { background: 'var(--warn-bg)', borderColor: 'var(--warn-border)', color: 'var(--warn-text)' },
    danger: { background: 'var(--danger-bg)', borderColor: 'var(--danger-border)', color: 'var(--danger-text)' },
    info: { background: 'var(--purple-950)', borderColor: 'var(--purple-800)', color: 'var(--purple-200)' },
  }[tone]
  return (
    <div className="flex gap-3 border-b px-4 py-3.5 text-[13px]" style={colours}>
      <span className="mt-0.5 shrink-0">{icon}</span>
      <div className="min-w-0 flex-1">
        <p className="mb-1 font-bold">{title}</p>
        {children}
      </div>
    </div>
  )
}
