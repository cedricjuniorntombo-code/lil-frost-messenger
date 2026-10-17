/*
# Add DELETE policy for messages

1. Security changes
- Add a DELETE policy on `messages` so authenticated users can delete their own messages.
- This was missing — without it, RLS blocks all DELETE operations on messages.

2. Important notes
- Only the sender (sender_id = auth.uid()) can delete their own messages.
- The recipient cannot delete messages they did not send.
*/

DROP POLICY IF EXISTS "messages_delete_own" ON public.messages;
CREATE POLICY "messages_delete_own"
  ON public.messages FOR DELETE
  TO authenticated
  USING (sender_id = auth.uid());
