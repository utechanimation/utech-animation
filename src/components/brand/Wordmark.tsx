import Owl from './Owl'

/**
 * "UTech's Animation" logo text.
 *  - inline  : one line, for the nav bar ("Animation" in the rainbow)
 *  - stacked : "UTECH'S" in spaced caps above a big "Animation" (sign-in, hero)
 */
export default function Wordmark({
  layout = 'inline',
  withOwl = false,
  className = '',
}: {
  layout?: 'inline' | 'stacked'
  withOwl?: boolean
  className?: string
}) {
  if (layout === 'stacked') {
    return (
      <div className={`flex flex-col items-center gap-1 ${className}`}>
        {withOwl && <Owl size={120} className="bob mb-2" />}
        <span className="pl-[.5em] text-[13px] font-bold tracking-[.5em]">UTECH&apos;S</span>
        <span className="font-display text-[64px] font-extrabold leading-[.9]">Animation</span>
        <span aria-hidden className="mt-3 h-1 w-[72px] rounded-full" style={{ background: 'var(--rainbow)' }} />
      </div>
    )
  }
  return (
    <span className={`inline-flex items-center gap-2 font-display text-[22px] font-extrabold leading-none ${className}`}>
      {withOwl && <Owl size={34} variant="mono" />}
      <span>
        UTech&apos;s <span className="rainbow-text">Animation</span>
      </span>
    </span>
  )
}
