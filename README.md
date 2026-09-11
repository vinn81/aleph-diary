# Plan Do See

계획(Plan), 실제 수행(Do), 회고(See)를 날짜별로 기록하는 공개형 개인 다이어리입니다. 화면은 Vercel에 배포하고 기록은 Neon PostgreSQL에 저장합니다.

## Neon DB 연결

1. Neon 프로젝트의 **SQL Editor**에서 `db/SETUP_ALL.sql` 전체를 한 번에 실행합니다. 새 DB와 기존 1단계 DB 모두 사용할 수 있습니다.
2. 파일에는 인증 스키마와 샘플 기록이 함께 들어 있습니다. 기존 기록은 유지되고, 샘플 기록은 없는 날짜만 추가됩니다.
3. Neon 대시보드의 **Connect**에서 pooled connection string을 복사합니다.
4. Vercel 프로젝트의 **Settings → Environment Variables**에 `DATABASE_URL`로 등록합니다.
5. GitHub에 변경 파일을 푸시한 뒤 Vercel에서 재배포합니다.

`DATABASE_URL`은 Production, Preview, Development 중 사용할 환경에 각각 등록합니다. 실제 연결 문자열은 `.env`나 소스 코드에 커밋하지 않습니다.

## 로컬 실행

```bash
npm install
cp .env.example .env.local
# .env.local의 DATABASE_URL을 실제 Neon 연결 문자열로 교체
npm run dev
```

## 저장 구조

- `diary_days`: 날짜와 오늘의 한 줄 목표
- `plans`: 계획, 완료 기준, 예상·실제 시간, 상태, 실제 기록
- `reviews`: 잘된 점, 달라진 점, 이유, 다음 행동

브라우저는 `/api/diary`만 호출하며 데이터베이스 연결 문자열은 서버 함수에서만 사용합니다. 기존 `localStorage` 초안 데이터는 DB가 비어 있을 때 최초 1회 서버로 이전됩니다. 이후 브라우저 저장소는 저장 실패 시 입력을 잃지 않기 위한 임시 초안에만 사용됩니다.

## 배포 확인

1. 목표, 계획, 실제 수행 내용과 회고를 작성합니다.
2. 페이지를 새로고침해 모든 내용이 남아 있는지 확인합니다.
3. 다른 브라우저나 시크릿 창에서 같은 배포 주소를 열어 동일한 기록이 보이는지 확인합니다.
4. 달력의 기록 표시와 지난 기록 목록이 DB 데이터와 일치하는지 확인합니다.
