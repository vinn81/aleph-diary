import { neon } from '@neondatabase/serverless';

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const STATUS = new Set(['open', 'partial', 'done']);
const PRIORITY = new Set(['높음', '보통', '낮음']);

class ValidationError extends Error {}

function text(value, max) {
  return String(value ?? '').trim().slice(0, max);
}

function minutes(value) {
  const parsed = Number(value || 0);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(1440, Math.round(parsed)));
}

function validateDay(date, day) {
  if (!DATE_PATTERN.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))) {
    throw new ValidationError('올바른 날짜가 필요합니다.');
  }
  if (!day || typeof day !== 'object' || !Array.isArray(day.plans)) {
    throw new ValidationError('올바른 다이어리 데이터가 필요합니다.');
  }
  if (day.plans.length > 100) throw new ValidationError('하루 계획은 최대 100개까지 저장할 수 있습니다.');

  const ids = new Set();
  const plans = day.plans.map((plan) => {
    const id = text(plan.id, 80);
    const title = text(plan.title, 200);
    if (!id || ids.has(id)) throw new ValidationError('계획 ID가 없거나 중복되었습니다.');
    if (!title) throw new ValidationError('계획 제목이 필요합니다.');
    ids.add(id);
    return {
      id,
      title,
      criteria: text(plan.criteria, 500),
      minutes: minutes(plan.minutes),
      priority: PRIORITY.has(plan.priority) ? plan.priority : '보통',
      status: STATUS.has(plan.status) ? plan.status : 'open',
      actualMinutes: minutes(plan.actualMinutes),
      actualNote: text(plan.actualNote, 2000),
      differenceNote: text(plan.differenceNote, 2000)
    };
  });

  const review = day.review && typeof day.review === 'object' ? day.review : {};
  return {
    goal: text(day.goal, 300),
    plans,
    review: {
      wentWell: text(review.wentWell, 2000),
      different: text(review.different, 2000),
      reason: text(review.reason, 2000),
      nextAction: text(review.nextAction, 2000)
    }
  };
}

function send(response, status, body) {
  response.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.end(JSON.stringify(body));
}

export default async function handler(request, response) {
  if (!process.env.DATABASE_URL) {
    return send(response, 503, { error: '서버의 데이터베이스 연결이 설정되지 않았습니다.' });
  }

  const sql = neon(process.env.DATABASE_URL);

  try {
    if (request.method === 'GET') {
      const [days, plans, reviews] = await sql.transaction([
        sql`SELECT id, diary_date::text AS diary_date, goal FROM diary_days ORDER BY diary_date DESC`,
        sql`SELECT id, day_id, title, completion_criteria, estimated_minutes, priority, status, actual_minutes, actual_note, difference_note FROM plans ORDER BY created_at, id`,
        sql`SELECT day_id, went_well, different, reason, next_action FROM reviews`
      ]);

      const result = {};
      const dayDates = new Map();
      for (const row of days) {
        dayDates.set(String(row.id), row.diary_date);
        result[row.diary_date] = { goal: row.goal || '', plans: [], review: {} };
      }
      for (const row of plans) {
        const date = dayDates.get(String(row.day_id));
        if (!date || !result[date]) continue;
        result[date].plans.push({
          id: row.id,
          title: row.title,
          criteria: row.completion_criteria || '',
          minutes: Number(row.estimated_minutes || 0),
          priority: row.priority,
          status: row.status,
          actualMinutes: Number(row.actual_minutes || 0),
          actualNote: row.actual_note || '',
          differenceNote: row.difference_note || ''
        });
      }
      for (const row of reviews) {
        const date = dayDates.get(String(row.day_id));
        if (!date || !result[date]) continue;
        result[date].review = {
          wentWell: row.went_well || '',
          different: row.different || '',
          reason: row.reason || '',
          nextAction: row.next_action || ''
        };
      }
      return send(response, 200, { days: result });
    }

    if (request.method === 'PUT') {
      const date = text(request.body?.date, 10);
      const day = validateDay(date, request.body?.day);
      const upserted = await sql`
        INSERT INTO diary_days (diary_date, goal)
        VALUES (${date}, ${day.goal})
        ON CONFLICT (diary_date) DO UPDATE SET goal = EXCLUDED.goal, updated_at = NOW()
        RETURNING id
      `;
      const dayId = upserted[0].id;
      const queries = [sql`DELETE FROM plans WHERE day_id = ${dayId}`];
      for (const plan of day.plans) {
        queries.push(sql`
          INSERT INTO plans (
            id, day_id, title, completion_criteria, estimated_minutes, priority,
            status, actual_minutes, actual_note, difference_note
          ) VALUES (
            ${plan.id}, ${dayId}, ${plan.title}, ${plan.criteria}, ${plan.minutes}, ${plan.priority},
            ${plan.status}, ${plan.actualMinutes}, ${plan.actualNote}, ${plan.differenceNote}
          )
        `);
      }
      queries.push(sql`
        INSERT INTO reviews (day_id, went_well, different, reason, next_action)
        VALUES (${dayId}, ${day.review.wentWell}, ${day.review.different}, ${day.review.reason}, ${day.review.nextAction})
        ON CONFLICT (day_id) DO UPDATE SET
          went_well = EXCLUDED.went_well,
          different = EXCLUDED.different,
          reason = EXCLUDED.reason,
          next_action = EXCLUDED.next_action,
          updated_at = NOW()
      `);
      await sql.transaction(queries);
      return send(response, 200, { ok: true, date });
    }

    response.setHeader('Allow', 'GET, PUT');
    return send(response, 405, { error: '지원하지 않는 요청입니다.' });
  } catch (error) {
    console.error('Diary API error', error);
    if (error instanceof ValidationError) return send(response, 400, { error: error.message });
    return send(response, 500, { error: '데이터베이스 요청을 처리하지 못했습니다.' });
  }
}
