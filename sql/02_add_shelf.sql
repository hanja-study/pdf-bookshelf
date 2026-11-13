-- =====================================================================
-- 문서 서재: 책장(주제별 분류) 칸 더하기
-- 01_doc_state.sql을 이미 실행한 프로젝트에 한 번만 실행 (SQL Editor → Run)
-- 연습용 · 이미 있는 표를 고칠 때는 create가 아니라 alter table
-- =====================================================================

alter table public.doc_state
  add column if not exists shelf text;               -- 책장 이름, 분류 없음이면 null

alter table public.doc_state
  drop constraint if exists shelf_len;
alter table public.doc_state
  add constraint shelf_len check (shelf is null or char_length(shelf) between 1 and 40);

-- 권한은 표 단위로 이미 주었으므로(01번의 grant) 새 칸에 따로 줄 필요 없음.
-- RLS도 줄 단위 규칙이라 그대로 적용됨.

-- 확인: shelf 칸이 보이면 됨
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'doc_state' order by ordinal_position;
