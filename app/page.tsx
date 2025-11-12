import { redirect } from 'next/navigation'
import { createClient } from '@/utils/supabase-server'
import constants from '@/lib/constants'

export default async function Home() {
  const supabase = await createClient()
  const session = await supabase.auth.getUser()
  if (session.data.user) {
    redirect(constants.DEFAULT_ROUTE)
  } else {
    redirect('/login')
  }
}
