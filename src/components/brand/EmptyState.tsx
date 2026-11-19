import Owl from './Owl'

/** Friendly empty state with the owl, used instead of emoji placeholders. */
export default function EmptyState({
  title,
  children,
  action,
}: {
  title: string
  children?: React.ReactNode
  action?: React.ReactNode
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-[20px] border-2 border-dashed border-line px-6 py-14 text-center">
      <Owl size={88} className="bob" />
      <p className="font-display text-xl font-extrabold">{title}</p>
      {children && <div className="max-w-sm text-sm text-muted">{children}</div>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  )
}
