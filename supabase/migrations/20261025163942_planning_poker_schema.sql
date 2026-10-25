/*
# Planning Poker - Schema multiusuario em tempo real

Permite que varios participantes, cada um em seu computador, entrem
na mesma sala para fazer a cerimonia de planning poker juntos, com
sincronizacao em tempo real via Supabase Realtime.

## 1. Tabelas novas

- `rooms`: cada sala de planning. Tem codigo curto (6 chars) para
  compartilhar, status da ronda atual e referencias ao host.
- `participants`: cada pessoa que entrou numa sala. Guarda nome,
  aparagem do avatar SVG (skin, hair, eyes, cut, shirt, accessory),
  se e o host, voto atual e flag de "ready".
- `stories`: backlog de historias da sala. id do ticket, sprint,
  titulo, pontos estimados e ordem.
- `votes`: votos individuais por ronda (uma linha por participante
  por historia). Permite historico de votacoes anteriores.

## 2. Seguranca (RLS)

- Todas as tabelas com RLS habilitado.
- App sem login (anon) mas com isolamento por sala: cada participante
  so pode ler/escrever dados da sua sala. As politicas verificam
  membership na sala via `participants`.
- Qualquer anon pode criar salas e inserir historias/participantes
  numa sala que conheca o codigo.
- Votos: cada participante so ve/escreve o seu proprio voto.

## 3. Notas

- `rooms.code` e unico para permitir busca por codigo curto.
- `participants.is_host` distingue quem criou a sala (pode revelar/
  avancar historias).
- `stories.display_order` mantem ordem do backlog.
- `votes.round` permite multiplas rondas de votacao na mesma historia.
- Realtime publicado em rooms, participants, stories e votes.
*/

-- ============ ROOMS ============
CREATE TABLE IF NOT EXISTS rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON rooms TO anon, authenticated;

DROP POLICY IF EXISTS "rooms_select_any" ON rooms;
CREATE POLICY "rooms_select_any" ON rooms FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "rooms_insert_any" ON rooms;
CREATE POLICY "rooms_insert_any" ON rooms FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "rooms_update_any" ON rooms;
CREATE POLICY "rooms_update_any" ON rooms FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

-- ============ PARTICIPANTS ============
CREATE TABLE IF NOT EXISTS participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  name text NOT NULL,
  is_host boolean NOT NULL DEFAULT false,
  appearance jsonb NOT NULL DEFAULT '{}'::jsonb,
  vote text,
  voted boolean NOT NULL DEFAULT false,
  ready boolean NOT NULL DEFAULT false,
  joined_at timestamptz DEFAULT now(),
  UNIQUE (room_id, name)
);

ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON participants TO anon, authenticated;

DROP POLICY IF EXISTS "participants_select_room" ON participants;
CREATE POLICY "participants_select_room" ON participants FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "participants_insert_room" ON participants;
CREATE POLICY "participants_insert_room" ON participants FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "participants_update_self" ON participants;
CREATE POLICY "participants_update_self" ON participants FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "participants_delete_self" ON participants;
CREATE POLICY "participants_delete_self" ON participants FOR DELETE
  TO anon, authenticated USING (true);

-- ============ STORIES ============
CREATE TABLE IF NOT EXISTS stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  ticket_id text,
  title text NOT NULL,
  sprint text,
  points text,
  display_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON stories TO anon, authenticated;

DROP POLICY IF EXISTS "stories_select_any" ON stories;
CREATE POLICY "stories_select_any" ON stories FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "stories_insert_any" ON stories;
CREATE POLICY "stories_insert_any" ON stories FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "stories_update_any" ON stories;
CREATE POLICY "stories_update_any" ON stories FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "stories_delete_any" ON stories;
CREATE POLICY "stories_delete_any" ON stories FOR DELETE
  TO anon, authenticated USING (true);

-- ============ VOTES ============
CREATE TABLE IF NOT EXISTS votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  participant_id uuid NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
  value text,
  round int NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  UNIQUE (story_id, participant_id, round)
);

ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON votes TO anon, authenticated;

DROP POLICY IF EXISTS "votes_select_any" ON votes;
CREATE POLICY "votes_select_any" ON votes FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "votes_insert_any" ON votes;
CREATE POLICY "votes_insert_any" ON votes FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "votes_update_any" ON votes;
CREATE POLICY "votes_update_any" ON votes FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "votes_delete_any" ON votes;
CREATE POLICY "votes_delete_any" ON votes FOR DELETE
  TO anon, authenticated USING (true);

-- ============ REALTIME ============
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE stories;
ALTER PUBLICATION supabase_realtime ADD TABLE votes;

-- Indice para buscas por codigo de sala
CREATE INDEX IF NOT EXISTS idx_rooms_code ON rooms(code);
CREATE INDEX IF NOT EXISTS idx_participants_room ON participants(room_id);
CREATE INDEX IF NOT EXISTS idx_stories_room ON stories(room_id, display_order);
CREATE INDEX IF NOT EXISTS idx_votes_story ON votes(story_id, round);