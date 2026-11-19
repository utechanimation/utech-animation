/**
 * Small decorative pieces used across pages. No client JS; all motion is CSS
 * (see globals.css) and stops when the visitor has "reduce motion" switched on.
 */

/** Drifting star layer. Put it inside an element with the `nebula` class. */
export function Stars() {
  return <div className="stars" aria-hidden />
}

/**
 * Paint drips that hang from the bottom of a banner into the content.
 * `color` should match the banner's bottom edge.
 */
export function Drip({ color = 'var(--purple-950)', className = '' }: { color?: string; className?: string }) {
  return (
    <svg
      viewBox="0 0 390 30"
      preserveAspectRatio="none"
      aria-hidden
      className={`block h-[22px] w-full md:h-[30px] ${className}`}
      style={{ marginTop: -1 }}
    >
      <path
        fill={color}
        d="M0 0 H390 V8 C380 8 378 26 368 26 C358 26 360 8 344 8 H300 C290 8 292 18 282 18 C272 18 274 8 262 8 H190 C180 8 178 30 166 30 C154 30 156 8 144 8 H90 C80 8 82 16 72 16 C62 16 64 8 54 8 H24 C16 8 16 22 8 22 C2 22 0 14 0 8 Z"
      />
    </svg>
  )
}

/** Bouncing-ball loader — the animator's first exercise, used instead of spinners. */
export function BouncingBall({ label = 'Loading…' }: { label?: string }) {
  return (
    <div role="status" className="flex flex-col items-center justify-end gap-0 pt-12">
      <span
        className="ball block h-9 w-9 rounded-full"
        style={{ background: 'radial-gradient(circle at 35% 30%, #e9d5ff, #a855f7 60%, #581c87)' }}
        aria-hidden
      />
      <span className="ball-shadow mt-1 block h-[7px] w-11 rounded-[50%] bg-black" aria-hidden />
      <span className="eyebrow mt-4">{label}</span>
    </div>
  )
}

/**
 * Full-screen purple drip that runs down and off the screen once, revealing
 * the page underneath. Used when a portfolio opens.
 */
export function DripReveal() {
  return (
    <div aria-hidden className="drip-wipe pointer-events-none fixed inset-0 z-[60] flex flex-col">
      <div className="flex-1" style={{ background: 'var(--accent-hover)' }} />
      <Drip color="var(--accent-hover)" className="!h-12" />
    </div>
  )
}
