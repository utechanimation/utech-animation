import LoginClient from './LoginClient'

// /auth/callback sends people back here with ?error=signin when sign-in fails.
export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams
  return <LoginClient signInFailed={Boolean(error)} />
}
