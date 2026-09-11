-- Plan Do See: new or existing database setup
-- Run this one file in Neon SQL Editor.
-- Existing records are preserved. Sample records are inserted only when their date is absent.

BEGIN;

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

ALTER TABLE diary_days ADD COLUMN IF NOT EXISTS user_id BIGINT REFERENCES users(id) ON DELETE CASCADE;
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

INSERT INTO diary_days (diary_date, goal)
SELECT sample.diary_date, sample.goal
FROM (VALUES
  ('2026-08-24'::date, '이번 주의 우선순위를 정리하고 가장 중요한 일부터 시작하기'),
  ('2026-08-25'::date, '오전에 집중 시간을 확보해 미뤄둔 작업의 첫 단계를 끝내기'),
  ('2026-08-26'::date, '회의와 작업 사이의 전환 시간을 줄이고 흐름을 지키기'),
  ('2026-08-27'::date, '작게라도 운동하고 저녁에는 일에서 벗어나는 시간 만들기'),
  ('2026-08-28'::date, '한 주의 기록을 돌아보고 다음 주에 유지할 습관 정하기')
) AS sample(diary_date, goal)
WHERE NOT EXISTS (
  SELECT 1 FROM diary_days AS existing WHERE existing.diary_date = sample.diary_date
);

INSERT INTO plans (id, day_id, title, completion_criteria, estimated_minutes, priority, status, actual_minutes, actual_note, difference_note)
SELECT sample.id, day.id, sample.title, sample.criteria, sample.estimated_minutes, sample.priority, sample.status, sample.actual_minutes, sample.actual_note, sample.difference_note
FROM (VALUES
  ('sample-20260824-plan', '2026-08-24'::date, '이번 주 핵심 업무 세 가지 정리', '해야 할 일을 적고 오늘 처리할 한 가지를 고른다', 35, '높음', 'done', 42, '프로젝트와 개인 일정을 한 화면에 모아 우선순위를 정리했다.', '생각보다 분류에 시간이 걸렸다.'),
  ('sample-20260824-walk', '2026-08-24'::date, '점심 후 20분 걷기', '동네를 한 바퀴 걸으며 휴대폰을 보지 않는다', 20, '낮음', 'done', 18, '날씨가 좋아 짧게 산책했다.', ''),
  ('sample-20260825-draft', '2026-08-25'::date, '미뤄둔 문서 초안 작성', '핵심 내용과 다음 단계까지 문서에 남긴다', 90, '높음', 'partial', 65, '목차와 핵심 사례까지 작성했다.', '오전 연락이 길어져 마무리하지 못했다.'),
  ('sample-20260825-lunch', '2026-08-25'::date, '점심을 천천히 먹기', '자리에서 벗어나 30분 동안 식사한다', 30, '보통', 'done', 30, '식사 중에는 알림을 꺼두었다.', ''),
  ('sample-20260826-meeting', '2026-08-26'::date, '회의 전에 결정할 질문 세 가지 준비', '회의 시작 전에 질문을 문서에 적어둔다', 25, '높음', 'done', 20, '결정이 필요한 내용을 미리 좁혀 회의가 짧아졌다.', ''),
  ('sample-20260826-focus', '2026-08-26'::date, '집중 작업 한 번 진행', '45분 동안 알림을 끄고 작업한 뒤 여유 시간을 남긴다', 50, '높음', 'done', 45, '한 번의 집중 작업을 끝내고 후속 요청을 처리했다.', '한 번만 계획하니 예상 밖 요청을 받을 여유가 생겼다.'),
  ('sample-20260827-exercise', '2026-08-27'::date, '가벼운 근력 운동 30분', '스쿼트와 스트레칭을 포함해 몸을 움직인다', 30, '보통', 'done', 35, '짧게 시작했지만 컨디션이 좋아 계획보다 조금 더 했다.', ''),
  ('sample-20260827-offline', '2026-08-27'::date, '저녁 9시 이후 업무 알림 끄기', '다음 날 아침까지 업무 앱을 열지 않는다', 5, '보통', 'done', 5, '알림을 끄고 책을 읽었다.', ''),
  ('sample-20260828-review', '2026-08-28'::date, '이번 주 계획과 실제 시간 비교', '차이가 큰 작업 두 개와 이유를 적는다', 30, '높음', 'done', 25, '문서 작업과 회의 준비의 차이를 확인했다.', ''),
  ('sample-20260828-reset', '2026-08-28'::date, '다음 주 첫 업무 예약하기', '월요일 오전 첫 한 시간을 미리 비워둔다', 15, '보통', 'done', 12, '월요일 오전에 문서 초안 시간을 확보했다.', '')
) AS sample(id, diary_date, title, criteria, estimated_minutes, priority, status, actual_minutes, actual_note, difference_note)
JOIN diary_days AS day ON day.diary_date = sample.diary_date AND day.user_id IS NULL
ON CONFLICT (id) DO NOTHING;

INSERT INTO reviews (day_id, went_well, different, reason, next_action)
SELECT day.id, sample.went_well, sample.different, sample.reason, sample.next_action
FROM (VALUES
  ('2026-08-24'::date, '아침에 우선순위를 정하니 중요한 일을 먼저 처리할 수 있었다.', '분류 작업이 예상보다 길어졌다.', '일정과 할 일을 한 번에 정리하려고 해서 초반 판단이 느려졌다.', '월요일에는 전날 적어둔 목록에서 바로 한 가지를 고른다.'),
  ('2026-08-25'::date, '문서의 뼈대를 만든 덕분에 다음 작업이 선명해졌다.', '초안을 끝까지 다듬지는 못했다.', '오전의 작은 요청들을 바로 처리하느라 집중 시간이 끊겼다.', '집중 시간에는 메신저를 한 번만 확인한다.'),
  ('2026-08-26'::date, '회의 전 질문을 준비해 결정이 빨라졌다.', '두 번째 집중 시간이 짧아졌다.', '회의 후 후속 확인이 예상보다 많았다.', '회의가 끝나기 전에 후속 담당자와 시간을 확정한다.'),
  ('2026-08-27'::date, '운동과 저녁 휴식 모두 지켜서 하루가 가볍게 끝났다.', '운동을 시작하기까지 미루는 시간이 있었다.', '퇴근 직후 바로 시작할 준비가 되어 있지 않았다.', '운동복을 아침에 미리 꺼내둔다.'),
  ('2026-08-28'::date, '한 주의 기록을 실제 시간 기준으로 돌아볼 수 있었다.', '계획을 너무 촘촘하게 잡은 날이 있었다.', '전환 시간과 예상 밖의 요청을 계획에 넣지 않았다.', '다음 주에는 하루에 여유 시간 30분을 남겨둔다.')
) AS sample(diary_date, went_well, different, reason, next_action)
JOIN diary_days AS day ON day.diary_date = sample.diary_date AND day.user_id IS NULL
ON CONFLICT (day_id) DO NOTHING;

COMMIT;
