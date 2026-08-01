import { supabase } from './supabaseClient.js';

// Zwraca zalogowana sesje + profil (z rola is_admin), albo przekierowuje
// na strone logowania jesli nikt nie jest zalogowany.
export async function requireSession() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = 'index.html';
    return null;
  }

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id, full_name, is_admin')
    .eq('id', session.user.id)
    .single();

  if (error || !profile) {
    console.error('Nie udalo sie pobrac profilu', error);
    await supabase.auth.signOut();
    window.location.href = 'index.html';
    return null;
  }

  return { session, profile };
}

export async function requireAdmin() {
  const ctx = await requireSession();
  if (!ctx) return null;
  if (!ctx.profile.is_admin) {
    window.location.href = 'dashboard.html';
    return null;
  }
  return ctx;
}

export function wireLogout(buttonId) {
  const btn = document.getElementById(buttonId);
  if (!btn) return;
  btn.addEventListener('click', async () => {
    await supabase.auth.signOut();
    window.location.href = 'index.html';
  });
}
