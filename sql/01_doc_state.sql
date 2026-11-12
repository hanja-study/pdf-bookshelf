-- =====================================================================
-- 문서 서재(PDF 뷰어) 기기 간 동기화용 테이블
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run
-- 연습용 · 문서 하나당 한 줄 (마지막으로 읽은 쪽 + 책갈피 목록)
-- =====================================================================

-- 1) 테이블 ------------------------------------------------------------
create table if not exists public.doc_state (
  user_id     uuid        not null default auth.uid()
                          references auth.users (id) on delete cascade,
  doc_name    text        not null,
  last_page   integer     not null default 1,
  bookmarks   jsonb       not null default '[]'::jsonb,
  updated_at  timestamptz not null,               -- 기기에서 마지막으로 고친 시각 (최신판 판정용)
  synced_at   timestamptz not null default now(), -- 서버에 들어온 시각 (참고용)
  primary key (user_id, doc_name),

  -- 2) 서버 쪽 검증: 브라우저 검사는 편의용이므로 DB가 한 번 더 막는다
  constraint doc_name_len   check (char_length(doc_name) between 1 and 255),
  constraint last_page_ok   check (last_page between 1 and 100000),
  constraint bookmarks_arr  check (jsonb_typeof(bookmarks) = 'array'
                                   and jsonb_array_length(bookmarks) <= 500),
  constraint bookmarks_size check (pg_column_size(bookmarks) <= 65536),
  constraint not_future     check (updated_at <= now() + interval '10 minutes')
);

comment on table public.doc_state is '문서 서재: 문서별 마지막 쪽과 책갈피 (기기 간 동기화)';

-- 3) 고칠 때마다 synced_at을 서버 시각으로 ----------------------------
create or replace function public.doc_state_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.synced_at := now();
  return new;
end;
$$;

drop trigger if exists doc_state_touch on public.doc_state;
create trigger doc_state_touch
  before insert or update on public.doc_state
  for each row execute function public.doc_state_touch();

-- 4) RLS: 로그인한 본인 줄만 읽고 쓰기 ---------------------------------
alter table public.doc_state enable row level security;

drop policy if exists "doc_state select own" on public.doc_state;
drop policy if exists "doc_state insert own" on public.doc_state;
drop policy if exists "doc_state update own" on public.doc_state;
drop policy if exists "doc_state delete own" on public.doc_state;

create policy "doc_state select own" on public.doc_state
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "doc_state insert own" on public.doc_state
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "doc_state update own" on public.doc_state
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "doc_state delete own" on public.doc_state
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 5) Data API 권한: 2026년부터 새 테이블은 자동으로 API에 열리지 않으므로 직접 허용
--    로그인한 사용자(authenticated)에게만. 비로그인(anon)에게는 주지 않는다.
--    어느 줄을 볼 수 있는지는 위의 RLS가 다시 거른다.
grant select, insert, update, delete on table public.doc_state to authenticated;

-- 6) 확인용 (실행 결과로 rowsecurity = true 가 보이면 됨) -------------
select tablename, rowsecurity from pg_tables where tablename = 'doc_state';
