import { createHash, randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { neon } from '@neondatabase/serverless';

const scrypt = promisify(scryptCallback);
const SESSION_DAYS = 14;
const USERNAME_PATTERN = /^[A-Za-z0-9가-힣._-]{2,80}$/;
class ValidationError extends Error {}

function send(response, status, body) {
  response.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.end(JSON.stringify(body));
}
function text(value, max) { return String(value ?? '').trim().slice(0, max); }
function cookieValue(request, name) {
  const cookies = request.headers.cookie || '';
  const match = cookies.split(';').map(item => item.trim()).find(item => item.startsWith(`${name}=`));
  return match ? decodeURIComponent(match.slice(name.length + 1)) : '';
}
function hashToken(token) { return createHash('sha256').update(token).digest('hex'); }
async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const derived = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return `scrypt$${salt}$${Buffer.from(derived).toString('hex')}`;
}
async function verifyPassword(password, stored) {
  const [, salt, expectedHex] = String(stored).split('$');
  if (!salt || !expectedHex) return false;
  const derived = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  const expected = Buffer.from(expectedHex, 'hex');
  return expected.length === derived.length && timingSafeEqual(expected, derived);
}
function setSessionCookie(response, token) {
  const secure = process.env.NODE_ENV === 'production' ? '; Secure' : '';
  response.setHeader('Set-Cookie', `diary_session=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${SESSION_DAYS * 86400}${secure}`);
}
function clearSessionCookie(response) { response.setHeader('Set-Cookie', 'diary_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0'); }
async function createSession(sql, userId, response) {
  const token = randomBytes(32).toString('base64url');
  await sql`INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (${hashToken(token)}, ${userId}, NOW() + (${SESSION_DAYS} * INTERVAL '1 day'))`;
  setSessionCookie(response, token);
}
export async function currentUser(request, sql) {
  const token = cookieValue(request, 'diary_session');
  if (!token) return null;
  const rows = await sql`SELECT users.id, users.username FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.token_hash = ${hashToken(token)} AND sessions.expires_at > NOW()`;
  return rows[0] || null;
}

export default async function handler(request, response) {
  if (!process.env.DATABASE_URL) return send(response, 503, { error: '서버의 데이터베이스 연결이 설정되지 않았습니다.' });
  const sql = neon(process.env.DATABASE_URL);
  try {
    if (request.method === 'GET') {
      const user = await currentUser(request, sql);
      return send(response, 200, { authenticated: Boolean(user), user: user ? { username: user.username } : null });
    }
    if (request.method !== 'POST') { response.setHeader('Allow', 'GET, POST'); return send(response, 405, { error: '지원하지 않는 요청입니다.' }); }
    const action = text(request.body?.action, 20);
    if (action === 'logout') {
      const token = cookieValue(request, 'diary_session');
      if (token) await sql`DELETE FROM sessions WHERE token_hash = ${hashToken(token)}`;
      clearSessionCookie(response);
      return send(response, 200, { ok: true });
    }
    const username = text(request.body?.username, 80), password = String(request.body?.password || '');
    if (!USERNAME_PATTERN.test(username)) throw new ValidationError('아이디는 2~80자의 한글, 영문, 숫자, ., _, -만 사용할 수 있습니다.');
    if (password.length < 8 || password.length > 200) throw new ValidationError('비밀번호는 8~200자로 입력해 주세요.');
    if (action === 'signup') {
      const passwordHash = await hashPassword(password);
      const created = await sql`INSERT INTO users (username, password_hash) VALUES (${username}, ${passwordHash}) ON CONFLICT (username) DO NOTHING RETURNING id, username`;
      if (!created[0]) return send(response, 409, { error: '이미 사용 중인 아이디입니다.' });
      await sql`UPDATE diary_days SET user_id = ${created[0].id} WHERE user_id IS NULL`;
      await createSession(sql, created[0].id, response);
      return send(response, 201, { ok: true, user: { username: created[0].username } });
    }
    if (action === 'login') {
      const users = await sql`SELECT id, username, password_hash FROM users WHERE username = ${username}`;
      if (!users[0] || !(await verifyPassword(password, users[0].password_hash))) return send(response, 401, { error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
      await createSession(sql, users[0].id, response);
      return send(response, 200, { ok: true, user: { username: users[0].username } });
    }
    throw new ValidationError('지원하지 않는 인증 요청입니다.');
  } catch (error) {
    console.error('Auth API error', error);
    if (error instanceof ValidationError) return send(response, 400, { error: error.message });
    return send(response, 500, { error: '인증 요청을 처리하지 못했습니다.' });
  }
}