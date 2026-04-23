-- ניקוי policies ופונקציות ישנים (למניעת שגיאות profiles)
drop policy if exists "Users can view own profile" on electricity_readings;
drop policy if exists "Users can view own profile" on vaad_bills;
drop policy if exists "Users can view own profile" on arnona_bills;
drop policy if exists "Users can view own profile" on cycles;
drop policy if exists "allow all" on electricity_readings;
drop policy if exists "allow all" on vaad_bills;
drop policy if exists "allow all" on arnona_bills;
drop policy if exists "allow all" on cycles;
drop function if exists get_couple_id() cascade;
drop function if exists auth_user_couple_id() cascade;

-- טבלת קריאות חשמל
create table electricity_readings (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now(),
  cycle_month integer not null,
  cycle_year integer not null,
  previous_reading numeric not null,
  current_reading numeric not null,
  kwh_used numeric generated always as (current_reading - previous_reading) stored,
  bill_amount numeric not null,
  unit_amount numeric generated always as (30 + (current_reading - previous_reading) * 0.6402) stored,
  mine_amount numeric generated always as (bill_amount - (30 + (current_reading - previous_reading) * 0.6402)) stored,
  paid_to_supplier boolean default false
);

-- טבלת חשבונות ועד צופים
create table vaad_bills (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now(),
  cycle_month integer not null,
  cycle_year integer not null,
  bill_month integer not null,
  bill_year integer not null,
  shimira numeric not null default 0,
  misim numeric not null default 0,
  mayim_a numeric not null default 0,
  mayim_b numeric not null default 0,
  total numeric generated always as (shimira + misim + mayim_a + mayim_b) stored,
  unit_amount numeric generated always as ((misim / 3.0) + (mayim_a / 2.0) + (mayim_b / 2.0)) stored,
  mine_amount numeric generated always as (shimira + (misim * 2.0 / 3.0) + (mayim_a / 2.0) + (mayim_b / 2.0)) stored,
  paid_to_supplier boolean default false
);

-- טבלת ארנונה וביוב
create table arnona_bills (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now(),
  cycle_month integer not null,
  cycle_year integer not null,
  arnona_amount numeric not null default 0,
  biyuv_amount numeric not null default 0,
  total numeric generated always as (arnona_amount + biyuv_amount) stored,
  unit_amount numeric generated always as ((arnona_amount / 3.0) + (biyuv_amount / 2.0)) stored,
  mine_amount numeric generated always as ((arnona_amount * 2.0 / 3.0) + (biyuv_amount / 2.0)) stored,
  paid_to_supplier boolean default false
);

-- טבלת סבבים (סיכום דו-חודשי)
create table cycles (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now(),
  cycle_month integer not null,
  cycle_year integer not null,
  unit_paid boolean default false,
  unit_paid_date timestamptz,
  unique(cycle_month, cycle_year)
);

-- הרשאות גישה פתוחה (כי זה שימוש אישי)
alter table electricity_readings enable row level security;
alter table vaad_bills enable row level security;
alter table arnona_bills enable row level security;
alter table cycles enable row level security;

create policy "allow all" on electricity_readings for all using (true) with check (true);
create policy "allow all" on vaad_bills for all using (true) with check (true);
create policy "allow all" on arnona_bills for all using (true) with check (true);
create policy "allow all" on cycles for all using (true) with check (true);

-- unique constraints (נדרשים כדי שה-upsert עם onConflict יעבוד)
alter table electricity_readings add constraint unique_elec_cycle unique (cycle_month, cycle_year);
alter table vaad_bills add constraint unique_vaad_cycle_bill unique (cycle_month, cycle_year, bill_month, bill_year);
alter table arnona_bills add constraint unique_arnona_cycle unique (cycle_month, cycle_year);
-- cycles כבר מוגדר עם unique(cycle_month, cycle_year) בהגדרת הטבלה למעלה


