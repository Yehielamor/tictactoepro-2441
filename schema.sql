CREATE TABLE users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE NOT NULL,
    email text UNIQUE NOT NULL,
    avatar_url text,
    theme_preference text DEFAULT 'classic',
    rating integer DEFAULT 1000,
    games_played integer DEFAULT 0,
    games_won integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE games (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    player1_id uuid REFERENCES users(id) ON DELETE SET NULL,
    player2_id uuid REFERENCES users(id) ON DELETE SET NULL,
    winner_id uuid REFERENCES users(id) ON DELETE SET NULL,
    board_state text DEFAULT '         ',
    status text DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed', 'abandoned')),
    winning_line integer[],
    current_turn uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE game_moves (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    player_id uuid REFERENCES users(id) ON DELETE SET NULL,
    move_position integer NOT NULL CHECK (move_position >= 0 AND move_position <= 8),
    move_symbol text NOT NULL CHECK (move_symbol IN ('X', 'O')),
    created_at timestamptz DEFAULT now()
);

CREATE TABLE leaderboard_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    rating integer NOT NULL,
    rank integer,
    week_start_date date NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, week_start_date)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_games_player1_id ON games(player1_id);
CREATE INDEX idx_games_player2_id ON games(player2_id);
CREATE INDEX idx_games_winner_id ON games(winner_id);
CREATE INDEX idx_games_status ON games(status);
CREATE INDEX idx_game_moves_game_id ON game_moves(game_id);
CREATE INDEX idx_game_moves_player_id ON game_moves(player_id);
CREATE INDEX idx_leaderboard_entries_user_id ON leaderboard_entries(user_id);
CREATE INDEX idx_leaderboard_entries_week_start_date ON leaderboard_entries(week_start_date);
CREATE INDEX idx_leaderboard_entries_rating ON leaderboard_entries(rating DESC);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_moves ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view all games" ON games FOR SELECT USING (true);
CREATE POLICY "Users can insert games they participate in" ON games FOR INSERT WITH CHECK (auth.uid() IN (player1_id, player2_id));
CREATE POLICY "Users can update games they participate in" ON games FOR UPDATE USING (auth.uid() IN (player1_id, player2_id, current_turn));

CREATE POLICY "Users can view all game moves" ON game_moves FOR SELECT USING (true);
CREATE POLICY "Users can insert moves for their turn" ON game_moves FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM games 
        WHERE games.id = game_moves.game_id 
        AND games.current_turn = auth.uid()
    )
);

CREATE POLICY "Users can view leaderboard" ON leaderboard_entries FOR SELECT USING (true);
CREATE POLICY "Only service role can modify leaderboard" ON leaderboard_entries FOR ALL USING (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_games_updated_at BEFORE UPDATE ON games FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_leaderboard_entries_updated_at BEFORE UPDATE ON leaderboard_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();