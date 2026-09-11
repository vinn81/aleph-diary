CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(80) NOT NULL UNIQUE,
  password_hash VARCHAR(300) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash VARCHAR(128) PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);

CREATE TABLE IF NOT EXISTS diary_days (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  diary_date DATE NOT NULL,
  goal VARCHAR(300) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE diary_days DROP CONSTRAINT IF EXISTS diary_days_diary_date_key;
CREATE UNIQUE INDEX IF NOT EXISTS diary_days_user_date_idx ON diary_days(user_id, diary_date);

CREATE TABLE IF NOT EXISTS plans (
  id VARCHAR(80) PRIMARY KEY,
  day_id BIGINT NOT NULL REFERENCES diary_days(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  completion_criteria VARCHAR(500) NOT NULL DEFAULT '',
  estimated_minutes INTEGER NOT NULL DEFAULT 0 CHECK (estimated_minutes BETWEEN 0 AND 1440),
  priority VARCHAR(10) NOT NULL DEFAULT '보통' CHECK (priority IN ('높음', '보통', '낮음')),
  status VARCHAR(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'partial', 'done')),
  actual_minutes INTEGER NOT NULL DEFAULT 0 CHECK (actual_minutes BETWEEN 0 AND 1440),
  actual_note VARCHAR(2000) NOT NULL DEFAULT '',
  difference_note VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS plans_day_id_idx ON plans(day_id);

CREATE TABLE IF NOT EXISTS reviews (
  day_id BIGINT PRIMARY KEY REFERENCES diary_days(id) ON DELETE CASCADE,
  went_well VARCHAR(2000) NOT NULL DEFAULT '',
  different VARCHAR(2000) NOT NULL DEFAULT '',
  reason VARCHAR(2000) NOT NULL DEFAULT '',
  next_action VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
