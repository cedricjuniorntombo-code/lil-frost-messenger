/*
# Fix: allow reading all participants in conversations I belong to

1. Problem
- The cp_select_own policy only let a user read rows where user_id = auth.uid().
- useConversations needs to read the OTHER participant's row to display their profile.
- RLS blocked that read, so the conversation list came back empty.

2. Security changes
- Replace cp_select_own with a policy that allows reading any participant row
  for conversations the caller is a member of. This is still scoped — a user
  can only see participants of conversations they themselves belong to.
*/

DROP POLICY IF EXISTS "cp_select_own" ON public.conversation_participants;
DROP POLICY IF EXISTS "cp_select_participant" ON public.conversation_participants;

CREATE POLICY "cp_select_participant"
  ON public.conversation_participants FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp2
      WHERE cp2.conversation_id = conversation_participants.conversation_id
        AND cp2.user_id = auth.uid()
    )
  );
