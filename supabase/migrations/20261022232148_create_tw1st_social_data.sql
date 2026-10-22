/*
# Create TW1ST social data

1. New Tables
- `profiles` stores the public TW1ST username and optional profile image for each signed-in account.
- `friend_requests` stores pending, accepted, or declined requests between two accounts.
- `friendships` stores accepted friendships once, using a canonical pair of user IDs.
- `messages` stores group messages and private messages with their sender and recipient.

2. Security
- Every table has Row Level Security enabled.
- Only signed-in users can access application data.
- Profiles are readable to signed-in users for username lookup, but each user can only create or edit their own profile.
- Friend requests and friendships are limited to the people involved.
- Messages are limited to the sender and intended recipient, while the general channel is readable to signed-in users.
- Grants are limited to the verbs used by the application.

3. Important Notes
- Profile IDs reference Supabase Auth users and are deleted with the account.
- Message history is persisted for the social chat; the AI chat remains intentionally session-only in the browser.
*/

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL UNIQUE CHECK (char_length(username) BETWEEN 2 AND 24),
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sender_id, receiver_id),
  CHECK (sender_id <> receiver_id)
);

CREATE TABLE IF NOT EXISTS public.friendships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_a, user_b),
  CHECK (user_a < user_b)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  channel text NOT NULL DEFAULT 'general' CHECK (channel = 'general' OR recipient_id IS NOT NULL),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS friend_requests_receiver_status_idx ON public.friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS friendships_user_a_idx ON public.friendships(user_a);
CREATE INDEX IF NOT EXISTS friendships_user_b_idx ON public.friendships(user_b);
CREATE INDEX IF NOT EXISTS messages_channel_created_idx ON public.messages(channel, created_at);
CREATE INDEX IF NOT EXISTS messages_private_created_idx ON public.messages(sender_id, recipient_id, created_at);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.friend_requests TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.friendships TO authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;

DROP POLICY IF EXISTS "profiles_read_authenticated" ON public.profiles;
CREATE POLICY "profiles_read_authenticated" ON public.profiles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "requests_read_involved" ON public.friend_requests;
CREATE POLICY "requests_read_involved" ON public.friend_requests FOR SELECT TO authenticated USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
DROP POLICY IF EXISTS "requests_create_own" ON public.friend_requests;
CREATE POLICY "requests_create_own" ON public.friend_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);
DROP POLICY IF EXISTS "requests_update_receiver" ON public.friend_requests;
CREATE POLICY "requests_update_receiver" ON public.friend_requests FOR UPDATE TO authenticated USING (auth.uid() = receiver_id) WITH CHECK (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "friendships_read_involved" ON public.friendships;
CREATE POLICY "friendships_read_involved" ON public.friendships FOR SELECT TO authenticated USING (auth.uid() = user_a OR auth.uid() = user_b);
DROP POLICY IF EXISTS "friendships_create_involved" ON public.friendships;
CREATE POLICY "friendships_create_involved" ON public.friendships FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_a OR auth.uid() = user_b);
DROP POLICY IF EXISTS "friendships_delete_involved" ON public.friendships;
CREATE POLICY "friendships_delete_involved" ON public.friendships FOR DELETE TO authenticated USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "messages_read_general_or_private" ON public.messages;
CREATE POLICY "messages_read_general_or_private" ON public.messages FOR SELECT TO authenticated USING (channel = 'general' OR auth.uid() = sender_id OR auth.uid() = recipient_id);
DROP POLICY IF EXISTS "messages_create_own" ON public.messages;
CREATE POLICY "messages_create_own" ON public.messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id AND (channel = 'general' OR recipient_id IS NOT NULL));