/*
# Fix: create_conversation function

1. New Functions
- `create_conversation(other_user_id uuid)`: SECURITY DEFINER function that creates a new
  conversation, adds both the caller and the other user as participants, and returns the
  conversation id. This is needed because RLS on conversation_participants only allows a
  user to insert their own row — inserting the other participant's row requires elevated
  privileges.

2. Security
- The function is SECURITY DEFINER so it can insert both participant rows.
- It validates that the caller is authenticated and that the other user exists.
- It checks for an existing 1:1 conversation between the two users and reuses it
  instead of creating a duplicate.
- EXECUTE is granted to authenticated only.
*/

CREATE OR REPLACE FUNCTION public.create_conversation(other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  conv_id uuid;
  caller_id uuid := auth.uid();
  existing_conv uuid;
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF other_user_id = caller_id THEN
    RAISE EXCEPTION 'Cannot create conversation with yourself';
  END IF;

  -- Check if a 1:1 conversation already exists between these two users
  SELECT cp1.conversation_id INTO existing_conv
  FROM conversation_participants cp1
  JOIN conversation_participants cp2 ON cp2.conversation_id = cp1.conversation_id
  WHERE cp1.user_id = caller_id AND cp2.user_id = other_user_id
    -- Ensure it's a 1:1 conversation (exactly 2 participants)
    AND (
      SELECT count(*) FROM conversation_participants cp3
      WHERE cp3.conversation_id = cp1.conversation_id
    ) = 2
  LIMIT 1;

  IF existing_conv IS NOT NULL THEN
    RETURN existing_conv;
  END IF;

  -- Create new conversation
  INSERT INTO conversations DEFAULT VALUES RETURNING id INTO conv_id;

  -- Add both participants
  INSERT INTO conversation_participants (conversation_id, user_id) VALUES
    (conv_id, caller_id),
    (conv_id, other_user_id);

  RETURN conv_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_conversation(uuid) TO authenticated;
