'use client'

import { useRouter } from 'next/navigation'
import { useRef, useTransition } from 'react'
import { Search } from 'lucide-react'

/**
 * Explore page controls. Everything lives in the URL (?q=&tag=&year=&mode=),
 * so results are rendered on the server and links can be shared.
 */
type Filters = { tag: string | null; q: string | null; year: number | null; mode: 'portfolios' | 'profiles' }

function useFilterNavigation(current: Filters) {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()

  const go = (next: Partial<Filters>) => {
    const f = { ...current, ...next }
    const params = new URLSearchParams()
    if (f.mode === 'portfolios') {
      if (f.tag) params.set('tag', f.tag)
      if (f.year) params.set('year', String(f.year))
    } else {
      params.set('mode', 'profiles')
    }
    if (f.q) params.set('q', f.q)
    const qs = params.toString()
    startTransition(() => router.push(qs ? `/?${qs}` : '/', { scroll: false }))
  }
  return { go, isPending }
}

/** Search box + "Work / Students" switch. Sits in the hero. */
export function SearchBox(props: Filters) {
  const { go, isPending } = useFilterNavigation(props)
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const onType = (value: string) => {
    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => go({ q: value.trim() || null }), 300)
  }

  return (
    <div className="flex w-full max-w-xl flex-col gap-3">
      <div role="group" aria-label="Search for" className="flex w-fit gap-1 rounded-2xl bg-[rgba(10,10,10,.6)] p-1">
        {(['portfolios', 'profiles'] as const).map(mode => (
          <button
            key={mode}
            type="button"
            aria-pressed={props.mode === mode}
            onClick={() => go({ mode })}
            className={`min-h-[40px] rounded-xl px-4 text-[13px] font-bold transition-colors ${
              props.mode === mode ? 'bg-accent-hover text-white' : 'text-soft hover:text-ink'
            }`}
          >
            {mode === 'portfolios' ? 'Work' : 'Students'}
          </button>
        ))}
      </div>

      <label htmlFor="search" className="sr-only">
        {props.mode === 'profiles' ? 'Search students by name' : 'Search work by title'}
      </label>
      <div
        className={`flex h-[52px] items-center gap-3 rounded-2xl border border-[rgba(233,213,255,.28)] bg-[rgba(10,10,10,.72)] pl-4 pr-2 backdrop-blur-md transition-opacity focus-within:border-accent ${
          isPending ? 'opacity-70' : ''
        }`}
      >
        <Search size={18} className="shrink-0 text-mist" aria-hidden />
        <input
          id="search"
          type="search"
          defaultValue={props.q ?? ''}
          placeholder={props.mode === 'profiles' ? 'Search students' : 'Search work'}
          onChange={e => onType(e.target.value)}
          className="h-10 min-w-0 flex-1 bg-transparent text-[15px] text-ink outline-none placeholder:text-muted"
        />
      </div>
    </div>
  )
}

/** Tag stickers + year picker. Shown under the hero in "Work" mode. */
export function FilterBar(props: Filters & { tags: { id: string; name: string }[]; years: number[] }) {
  const { go, isPending } = useFilterNavigation(props)
  const tagOptions = [{ name: 'All', value: null as string | null }, ...props.tags.map(t => ({ name: t.name, value: t.name }))]

  return (
    <div className={`flex flex-col gap-3 transition-opacity md:flex-row md:items-center md:justify-between ${isPending ? 'opacity-70' : ''}`}>
      <div
        role="group"
        aria-label="Filter by tag"
        className="sticker-row -mx-4 flex gap-2.5 overflow-x-auto px-4 py-2 [scrollbar-width:none] md:mx-0 md:flex-wrap md:overflow-visible md:px-0"
      >
        {tagOptions.map(tag => (
          <button
            key={tag.name}
            type="button"
            aria-pressed={props.tag === tag.value}
            onClick={() => go({ tag: tag.value })}
            className="sticker shrink-0"
          >
            {tag.name}
          </button>
        ))}
      </div>

      {props.years.length > 0 && (
        <div className="flex items-center gap-2">
          <label htmlFor="year" className="text-[13px] font-semibold text-muted">Year</label>
          <select
            id="year"
            value={props.year ?? ''}
            onChange={e => go({ year: e.target.value ? Number(e.target.value) : null })}
            className="field !min-h-[40px] !w-auto !rounded-full !py-0 pr-8 text-[13px] font-bold"
          >
            <option value="">Any year</option>
            {props.years.map(y => (
              <option key={y} value={y}>{y}</option>
            ))}
          </select>
        </div>
      )}
    </div>
  )
}
