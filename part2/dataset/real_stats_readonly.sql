-- Campus Threads. Выполняйте запросы по одному в Neon SQL Editor или pgAdmin.
-- Каждый запрос только читает данные. Адреса почты, логины и хеши не выгружаются.

-- 1. Новые регистрации по неделям, факультетам и курсам (локальные даты Алматы).
SELECT date_trunc('week', (u.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Almaty')::date AS week,
       f.short_name AS faculty, s.year_of_study, count(*) AS registrations
FROM public.users AS u
JOIN public.students AS s USING (user_id)
JOIN public.faculties AS f USING (faculty_id)
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- 2. Сообщества и их текущие участники, треды и ответы.
-- Сначала считаем каждую метрику отдельно, чтобы соединение не размножало строки.
WITH memberships AS (
    SELECT community_id, count(*) AS members
    FROM public.community_members GROUP BY community_id
), posts AS (
    SELECT community_id,
           count(*) FILTER (WHERE parent_post_id IS NULL) AS threads,
           count(*) FILTER (WHERE parent_post_id IS NOT NULL) AS replies
    FROM public.posts WHERE community_id IS NOT NULL GROUP BY community_id
)
SELECT c.community_id, c.name,
       coalesce(m.members, 0) AS members,
       coalesce(p.threads, 0) AS threads, coalesce(p.replies, 0) AS replies
FROM public.communities AS c
LEFT JOIN memberships AS m USING (community_id)
LEFT JOIN posts AS p USING (community_id)
ORDER BY members DESC, c.name;

-- 3. Выдача пропусков и заполняемость мероприятий.
SELECT e.event_id, e.title, e.starts_at AT TIME ZONE 'Asia/Almaty' AS starts_at_almaty,
       e.capacity, count(t.ticket_id) AS tickets_issued,
       greatest(e.capacity - count(t.ticket_id), 0) AS seats_left,
       round(100.0 * count(t.ticket_id) / e.capacity, 2) AS fill_pct
FROM public.events AS e
LEFT JOIN public.event_tickets AS t USING (event_id)
GROUP BY e.event_id, e.title, e.starts_at, e.capacity
ORDER BY e.starts_at, e.event_id;

-- 4. Записи по дням из таблиц. Удалённые посты, снятые лайки и отменённые подписки здесь не видны.
WITH actions AS (
    SELECT created_at AT TIME ZONE 'UTC' AS occurred_at,
           CASE WHEN parent_post_id IS NULL THEN 'thread' ELSE 'reply' END AS action FROM public.posts
    UNION ALL SELECT liked_at AT TIME ZONE 'UTC', 'like' FROM public.likes
    UNION ALL SELECT followed_at AT TIME ZONE 'UTC', 'follow' FROM public.follows
    UNION ALL SELECT joined_at AT TIME ZONE 'UTC', 'membership' FROM public.community_members
    UNION ALL SELECT issued_at, 'ticket' FROM public.event_tickets
)
SELECT (occurred_at AT TIME ZONE 'Asia/Almaty')::date AS day, action, count(*) AS records
FROM actions GROUP BY 1, 2 ORDER BY 1, 2;
