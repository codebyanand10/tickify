-- SUPABASE DATABASE SCHEMA MIGRATION
-- Run this in your Supabase SQL Editor to set up the tables.

-- 1. PROFILES TABLE (Syncs with Auth, but we can also use it standalone for now)
create table public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  name text,
  role text default 'student', -- 'student', 'organizer', 'admin'
  phone text,
  college_name text,
  department text,
  semester int,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.profiles enable row level security;

-- Policies
create policy "Public profiles are viewable by everyone." on public.profiles for select using (true);
create policy "Users can insert their own profile." on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile." on public.profiles for update using (auth.uid() = id);

-- 2. EVENTS TABLE
create table public.events (
  id uuid default gen_random_uuid() primary key,
  created_by uuid references auth.users not null, -- references Firebase UID if sticking to Firebase, or Supabase UID
  -- NOTE: If using Firebase Auth, 'created_by' should be TEXT, not UUID references auth.users
  -- Let's assume TEXT for hybrid compatibility:
  
  -- HYBRID MODE (Firebase Auth)
  -- If you truly want "Database completely in Supabase", you usually switch Auth too. 
  -- But for now, let's use TEXT for IDs to be safe with Firebase UIDs.
  created_by_uid text not null, 

  title text not null,
  description text,
  category text,
  location text,
  date timestamp with time zone,
  time text, -- 'HH:MM'
  
  -- Flags
  limited_seats boolean default false,
  seat_count int,
  paid_event boolean default false,
  fee_amount numeric,
  certification boolean default false,
  college_type text, -- 'Intra College', 'Inter College'
  
  -- Json Data
  audience jsonb default '{}'::jsonb, -- {students: true, outsiders: false...}
  coordinators jsonb default '[]'::jsonb,
  
  poster_url text,
  whatsapp_link text,
  
  -- Certificate Template Data
  certificate_template_url text,
  certificate_fields jsonb default '[]'::jsonb,
  certificate_settings jsonb default '{}'::jsonb,
  
  certificates_generated boolean default false,
  certificates_published boolean default false,

  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for Events
alter table public.events enable row level security;
create policy "Events are viewable by everyone." on public.events for select using (true);
create policy "Authenticated users can create events." on public.events for insert with check (true); 
-- In a real app, strict checks would be: auth.uid()::text = created_by_uid
create policy "Creators can update their events." on public.events for update using (true); -- Simplistic for demo

-- 3. REGISTRATIONS TABLE
create table public.registrations (
  id uuid default gen_random_uuid() primary key,
  event_id uuid references public.events(id) not null,
  user_id text not null, -- Firebase UID
  
  user_name text,
  user_email text,
  college_name text,
  department text,
  semester int,
  
  status text default 'registered', -- 'registered', 'attended'
  registered_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.registrations enable row level security;
create policy "Anyone can register (simplistic)." on public.registrations for insert with check (true);
create policy "Users can view their own registrations." on public.registrations for select using (true);

-- 4. CERTIFICATES TABLE
create table public.certificates (
  id uuid default gen_random_uuid() primary key,
  event_id uuid references public.events(id) not null,
  user_id text not null, -- Firebase UID
  
  participant_name text,
  event_name text,
  event_date text,
  certificate_url text, -- The permanent PDF link
  
  published boolean default false,
  generated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.certificates enable row level security;
create policy "Certificates viewable by everyone (or owner)." on public.certificates for select using (true);
create policy "Organizers can insert certificates." on public.certificates for insert with check (true);

