-- =====================================================================
-- خطّي (Khatti) — مخطط قاعدة البيانات
-- شغّل هذا الملف كاملاً في: Supabase Dashboard → SQL Editor → Run
-- =====================================================================
create extension if not exists pgcrypto;

-- 1) السائقون
create table if not exists public.drivers (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  phone               text not null,
  car_model           text,
  capacity            int  not null default 7 check (capacity > 0),
  route_areas         text[] not null default '{}',
  school_name         text,
  network_code        text not null unique,
  subscription_status text not null default 'trial' check (subscription_status in ('trial','active','suspended')),
  subscription_end    date not null default (current_date + 14)
);

-- 2) شبكة السائقين
create table if not exists public.driver_network (
  id             uuid primary key default gen_random_uuid(),
  driver_id      uuid not null references public.drivers(id) on delete cascade,
  peer_driver_id uuid not null references public.drivers(id) on delete cascade,
  unique (driver_id, peer_driver_id),
  check (driver_id <> peer_driver_id)
);

-- 3) الطلاب
create table if not exists public.students (
  id                         uuid primary key default gen_random_uuid(),
  driver_id                  uuid not null references public.drivers(id) on delete cascade,
  transferred_from_driver_id uuid references public.drivers(id) on delete set null,
  student_name               text not null,
  parent_name                text,
  parent_phone               text not null,
  area                       text,
  school_name                text,
  lat                        double precision,
  lng                        double precision,
  status         text not null default 'pending'  check (status in ('pending','approved','overflow','transferred')),
  absence_status text not null default 'present'  check (absence_status in ('present','morning_absent','return_absent','full_absent')),
  pickup_status  text not null default 'waiting'  check (pickup_status in ('waiting','near','picked_up')),
  monthly_fee    numeric not null default 0,
  fee_paid       boolean not null default false
);
create index if not exists students_driver_idx on public.students(driver_id);
create index if not exists students_phone_idx  on public.students(parent_phone);

-- 4) Realtime
do $$
begin
  begin alter publication supabase_realtime add table public.students;       exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.drivers;        exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.driver_network; exception when duplicate_object then null; end;
end $$;

-- 5) سياسات الوصول (RLS)
-- ⚠️ تحذير: هذه السياسات مفتوحة لمفتاح anon لتعمل النسخة الأولى بدون تسجيل دخول حقيقي.
-- أي شخص يملك المفتاح يستطيع القراءة والتعديل. قبل استقبال عملاء حقيقيين:
-- فعّل Supabase Auth للسائقين وقيّد السياسات (driver_id = auth.uid()) ونقل
-- عمليات ولي الأمر (البحث بالموبايل / تسجيل الغياب) إلى دوال RPC أو Edge Functions.
alter table public.drivers        enable row level security;
alter table public.driver_network enable row level security;
alter table public.students       enable row level security;

drop policy if exists "khatti_open_drivers"  on public.drivers;
drop policy if exists "khatti_open_network"  on public.driver_network;
drop policy if exists "khatti_open_students" on public.students;
create policy "khatti_open_drivers"  on public.drivers        for all to anon, authenticated using (true) with check (true);
create policy "khatti_open_network"  on public.driver_network for all to anon, authenticated using (true) with check (true);
create policy "khatti_open_students" on public.students       for all to anon, authenticated using (true) with check (true);

-- 6) (اختياري) سائق تجريبي لتبدأ به — احذفه بعد التجربة
-- insert into public.drivers (name, phone, car_model, capacity, route_areas, school_name, network_code, subscription_status, subscription_end)
-- values ('كابتن محمود الشاذلي','01099887766','فان 7 مقاعد',7,array['الحي الأول','الحي الثاني'],'مدرسة النيل الدولية','SH-101','active',current_date+30);
