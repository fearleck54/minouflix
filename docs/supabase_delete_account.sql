-- MinouFlix : suppression de compte depuis l'appli (Réglages > À propos > Supprimer mon compte)
-- À exécuter une fois dans Supabase > SQL Editor. L'appli appelle POST /rest/v1/rpc/delete_account avec le jeton de l'utilisateur.
-- La fonction ne supprime que l'utilisateur connecté (auth.uid()), jamais un autre.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'non connecté';
  end if;
  delete from public.user_data where user_id = me;
  delete from auth.users where id = me;     -- supprime aussi ses sessions et identités (cascade Supabase)
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- l'API REST recharge son cache de schéma (sinon « fonction introuvable » pendant quelques minutes)
notify pgrst, 'reload schema';
