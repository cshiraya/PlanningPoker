/*
# Add game state columns to rooms

## 1. Modified tables
- `rooms`: added `current_story_id` (references stories, nullable) to
  track which story is active, and `revealed` (boolean, default false)
  to track whether cards are revealed for the current round.

## 2. Security
- No new policies needed; existing rooms policies cover UPDATE.
*/

ALTER TABLE rooms
  ADD COLUMN IF NOT EXISTS current_story_id uuid REFERENCES stories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS revealed boolean NOT NULL DEFAULT false;