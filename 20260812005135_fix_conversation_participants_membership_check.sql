/*
# Fix conversation history membership lookup

1. New Functions
- `is_conversation_member(conversation_id uuid)`: checks membership using the caller's
  authenticated id while running with controlled owner privileges, so the participant
  SELECT policy can safely inspect membership without recursive RLS evaluation.

2. Modified Policies
- Replace the self-referencing participant SELECT policy with a call to the helper.
- Users can read all participant rows only for conversations they belong to.
- Users cannot read participant rows from unrelated conversations.

3. Security
- The helper sets a fixed search path and is executable only by authenticated users.
- Anonymous callers cannot use the helper.
*/

CREATE OR REPLACE FUNCTION public.is_conversation_member(target_conversation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversation_participants
    WHERE conversation_id = target_conversation_id
      AND user_id = auth.uid()
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_conversation_member(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_conversation_member(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(uuid) TO authenticated;

DROP POLICY IF EXISTS "cp_select_participant" ON public.conversation_participants;
CREATE POLICY "cp_select_participant"
  ON public.conversation_participants FOR SELECT
  TO authenticated USING (public.is_conversation_member(conversation_id));
