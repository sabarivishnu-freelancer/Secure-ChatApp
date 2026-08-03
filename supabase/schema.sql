-- Supabase schema for Secure Chat prototype
-- Run this SQL in Supabase SQL editor or as a migration

-- Store users' public keys (for E2E key exchange)
create table if not exists public_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_key text not null,
  updated_at timestamptz default now()
);

-- Store encrypted messages
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  sender uuid references auth.users(id) on delete set null,
  receiver uuid references auth.users(id) on delete set null,
  ciphertext text not null,
  created_at timestamptz default now()
);

create index if not exists idx_messages_created_at on messages(created_at desc);
