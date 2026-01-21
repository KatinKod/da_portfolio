-- Топ-10 категорий (название и количество) с самым большим количеством отменённых заказов за период с 01.04.2025 по 30.06.2025

SELECT c.category_id,
       c.name AS category_name,
       COUNT(DISTINCT o.order_id) AS order_count
FROM marketplace.orders o
JOIN marketplace.order_items oi ON o.order_id = oi.order_id
JOIN marketplace.products p ON oi.product_id = p.product_id
JOIN marketplace.categories c ON p.category_id = c.category_id
WHERE o.status = 'canceled'
      and o.order_date BETWEEN '2025-04-01' AND '2025-06-30'
GROUP BY c.category_id, c.name
ORDER BY order_count DESC
LIMIT 10

-- Топ-10 пользователей (email и сумма заказов) с самой большой суммой заказов без учёта отменённых за период с 01.03.2025' по 31.05.2025

SELECT u.email,
       sum(o.total_amount) AS average_order_value
FROM marketplace.orders o
JOIN marketplace.users u ON o.buyer_id = u.user_id
where o.status != 'canceled'
      AND o.order_date >= '2025-03-01'          
      AND o.order_date < '2025-05-31'           
GROUP BY  u.email
ORDER BY average_order_value DESC
LIMIT 10

--  Для каждого пользователя и каждого месяца посчитать сумму заказов, а затем вычислить нарастающий итог по месяцам

WITH monthly_user_revenue AS (
    SELECT o.buyer_id AS user_id,
           DATE_TRUNC('month', o.order_date) AS order_month,
           SUM(o.total_amount) AS monthly_order_sum
    FROM marketplace.orders o
    WHERE o.status IN ('paid', 'shipped')
    GROUP BY o.buyer_id, 
             DATE_TRUNC('month', o.order_date)
)
SELECT user_id,
       order_month,
       monthly_order_sum,
       SUM(monthly_order_sum) OVER (PARTITION BY user_id ORDER BY order_month) AS cumulative_order_sum
FROM  monthly_user_revenue
ORDER BY user_id, order_month

-- Конверсия в заказ
 
WITH all_users AS (
    SELECT COUNT(user_id) AS total_users 
    FROM marketplace.users
),
buying_users AS (
    SELECT COUNT(DISTINCT buyer_id) AS active_buyers 
    FROM marketplace.orders
)
SELECT ROUND((SELECT active_buyers::NUMERIC FROM buying_users) / 
            (SELECT total_users::NUMERIC FROM all_users),1) AS conversion_rate
            
-- сколько товаров покупают в среднем в одном заказе
         
WITH order_products AS (
    SELECT order_id,
           SUM(quantity) AS products_in_order
    FROM marketplace.order_items
    GROUP BY order_id
)
SELECT ROUND(AVG(products_in_order::NUMERIC),2) AS avg_products_per_order
FROM order_products

-- Retention Rate первого месяца для каждой когорты — отношение активных пользователей в первый месяц к количеству зарегистрированных пользователей

WITH 
-- Все зарегистрированные пользователи с датой регистрации 
user_cohorts AS (
    SELECT DATE_TRUNC('month', registration_date) AS cohort_month,
           COUNT(user_id) AS total_users
    FROM marketplace.users
    GROUP BY cohort_month
),
-- Активные пользователи в первый месяц после регистрации
active_users AS (
    SELECT DATE_TRUNC('month', u.registration_date) AS cohort_month,
           COUNT(DISTINCT o.buyer_id) AS active_users_count
    FROM marketplace.users u
    JOIN marketplace.orders o ON u.user_id = o.buyer_id
    WHERE o.order_date BETWEEN u.registration_date AND (u.registration_date + INTERVAL '1 month')
    GROUP BY cohort_month
)
select c.cohort_month,
       c.total_users,
       COALESCE(a.active_users_count, 0) AS active_users,
       ROUND(COALESCE(a.active_users_count, 0)::NUMERIC / c.total_users::NUMERIC, 2) AS retention_rate
FROM user_cohorts c
LEFT JOIN active_users a ON c.cohort_month = a.cohort_month
ORDER BY c.cohort_month

-- LTV на пользователя для каждой когорты - суммарная выручка за 3 месяца/количество зарегистрированных пользователей в когорте.  

WITH cohort_users AS (
    select DATE_TRUNC('month', registration_date) AS cohort_month,
           COUNT(DISTINCT user_id) AS total_users
 FROM marketplace.users
 GROUP BY cohort_month
),
cohort_revenue AS (
    SELECT DATE_TRUNC('month', u.registration_date) AS cohort_month,
           SUM(o.total_amount::NUMERIC) AS revenue_first_3_months
 FROM marketplace.users u
 JOIN marketplace.orders o ON u.user_id = o.buyer_id
 WHERE o.order_date >= u.registration_date
       AND o.order_date < u.registration_date + INTERVAL '3 months'
 GROUP BY cohort_month
)
select c.cohort_month,
       c.total_users,
       COALESCE(r.revenue_first_3_months, 0) AS revenue_first_3_months,
       COALESCE(ROUND(r.revenue_first_3_months::numeric / c.total_users::numeric, 2),0) AS LTV_per_user
FROM cohort_users c
LEFT JOIN cohort_revenue r ON c.cohort_month = r.cohort_month
ORDER BY c.cohort_month

-- ARPU - средний доход на одного зарегистрированного покупателя за с 01.01.2025 по 31.05.2025

WITH total_revenue AS (
    SELECT SUM(total_amount) AS revenue
    FROM marketplace.orders
    WHERE order_date BETWEEN '2025-01-01' AND '2025-05-31'
    AND status != 'canceled'
),
total_users AS (
    SELECT COUNT(DISTINCT user_id) AS users_count
    FROM marketplace.users
    WHERE registration_date <= '2025-05-31'
)
SELECT ROUND(tr.revenue::numeric / tu.users_count::numeric) AS ARPU
FROM total_revenue tr, total_users tu

-- DAU по дням за май 2025
 
select order_date::date AS date,
       COUNT(DISTINCT buyer_id) AS dau
FROM marketplace.orders 
WHERE order_date >= '2025-05-01'
      AND order_date <= '2025-05-31'
GROUP BY date
ORDER BY date

-- ARPPU — средняя выручка на одного платящего пользователя за май 2025

WITH new AS (
    SELECT DISTINCT buyer_id AS paying_user,
           total_amount AS amount
    FROM marketplace.orders o
    WHERE order_date >= '2025-05-01' 
          AND order_date <= '2025-05-31' 
          AND o.status NOT LIKE 'canceled'
)
SELECT 
    SUM(cast(new.amount as numeric)) AS total_revenue,
    COUNT(DISTINCT paying_user) AS paying_users_count,
    ROUND(SUM(cast(new.amount as numeric)) / COUNT(DISTINCT paying_user), 2) AS arppu
FROM new


