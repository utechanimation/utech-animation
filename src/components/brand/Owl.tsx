/**
 * The UTech's Animation owl: a black owl with a painter's beret, a scarf and
 * a paintbrush tilted outward. Plain SVG, no client JS.
 *
 * variant="color" — purple scarf and paint (app icon, sign-in, empty states)
 * variant="mono"  — black and white only (small sizes, favicon)
 */
type OwlProps = {
  size?: number
  variant?: 'color' | 'mono'
  /** Text for screen readers. Leave empty when the owl is decoration. */
  title?: string
  className?: string
}

export default function Owl({ size = 64, variant = 'color', title, className }: OwlProps) {
  const color = variant === 'color'
  const scarf = color ? '#9333ea' : '#000'
  const stripe = color ? '#fafafa' : '#fff'
  const paint = color ? '#c084fc' : '#fff'
  const outline = '#fff'

  return (
    <svg
      viewBox="0 0 250 250"
      width={size}
      height={size}
      className={className}
      role={title ? 'img' : undefined}
      aria-label={title || undefined}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {/* body */}
      <path
        d="M110 52 C160 52 178 100 176 150 C174 200 146 228 110 228 C74 228 46 200 44 150 C42 100 60 52 110 52 Z"
        fill="#000" stroke={outline} strokeWidth={4} strokeLinejoin="round"
      />
      {/* heart-shaped face */}
      <path
        d="M110 98 C92 82 58 88 56 120 C54 148 80 166 110 180 C140 166 166 148 164 120 C162 88 128 82 110 98 Z"
        fill="#fff"
      />
      {/* eyes, glints, brows, beak */}
      <path d="M70 122 C80 115 92 117 102 126 C96 135 79 134 70 122 Z" fill="#000" />
      <path d="M150 122 C140 115 128 117 118 126 C124 135 141 134 150 122 Z" fill="#000" />
      <circle cx="93" cy="126" r="2.4" fill="#fff" />
      <circle cx="127" cy="126" r="2.4" fill="#fff" />
      <path d="M66 113 L99 120 M154 113 L121 120" stroke="#000" strokeWidth={3.5} strokeLinecap="round" />
      <path d="M103 141 L117 141 L110 157 Z" fill="#000" />
      {/* painter's beret, centred */}
      <g stroke={outline} strokeWidth={4} strokeLinejoin="round" strokeLinecap="round">
        <path
          d="M36 90 C22 62 64 40 110 40 C156 40 198 62 184 90 C174 101 144 102 110 102 C76 102 46 101 36 90 Z"
          fill="#000"
        />
        <path d="M50 95 C80 92 140 92 170 95" fill="none" strokeWidth={2.5} />
        <path d="M110 40 C108 30 116 24 123 28" fill="none" />
      </g>
      {color && (
        <g fill={paint}>
          <circle cx="140" cy="58" r="6" />
          <circle cx="152" cy="66" r="3" />
          <circle cx="130" cy="52" r="2.6" />
          <circle cx="156" cy="56" r="2.2" />
        </g>
      )}
      {/* scarf */}
      <g stroke={outline} strokeWidth={3.5} strokeLinejoin="round" strokeLinecap="round">
        <path d="M62 188 L50 230 L74 233 L82 194 Z" fill={scarf} />
        <path d="M48 172 C80 192 140 192 172 172 L174 194 C140 216 80 216 46 194 Z" fill={scarf} />
        <path d="M52 230 L50 238 M58 231 L57 239 M64 232 L64 240 M70 232 L71 240" fill="none" />
      </g>
      <path d="M80 189 L76 208 M108 192 L108 212 M136 189 L140 208" stroke={stripe} strokeWidth={5} strokeLinecap="round" />
      {/* paintbrush, tilted outward */}
      <g transform="translate(188 228) rotate(18)" stroke={outline} strokeWidth={3.5} strokeLinejoin="round">
        <path d="M-4 0 L4 0 L6 -72 L-6 -72 Z" fill="#000" />
        <rect x="-8" y="-94" width="16" height="22" rx="2" fill="#fff" />
        <path d="M-8 -84 L8 -84" stroke="#000" strokeWidth={2} />
        <path d="M-8 -94 C-10 -112 -4 -126 0 -138 C4 -126 10 -112 8 -94 Z" fill="#000" />
        <path d="M-6 -114 C-3 -124 -1 -131 0 -138 C1 -131 3 -124 6 -114 C2 -117 -2 -117 -6 -114 Z" fill={paint} stroke="none" />
        <circle cx="-3" cy="-149" r="3.6" fill={paint} stroke="none" />
        <circle cx="2" cy="-158" r="2.2" fill={paint} stroke="none" />
      </g>
    </svg>
  )
}
