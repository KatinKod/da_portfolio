/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

-- Исследовательский анализ данных
-- Исследование доли платящих игроков:

-- 1.1. Доля платящих пользователей по всем данным:
WITH  pay_player AS (
                   SELECT COUNT (id) AS payer_player
                   FROM fantasy.users 
                   WHERE payer = 1), --считаем количество платящих игроков
      count_player AS (
                   SELECT COUNT (id) AS total_players
                   FROM fantasy.users)--считаем общее количество игроков
        SELECT  
              round(((payer_player::REAL / total_players::REAL)*100)::numeric,2) as dol_proc
        FROM count_player AS cp
        CROSS JOIN pay_player AS pp;  --доля платящих пользователей 
        
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH pay_player_race AS (
                    SELECT race,
                           COUNT (id) AS payer_player_race
                    FROM fantasy.users u 
                    LEFT JOIN fantasy.race r USING (race_id)
                    WHERE payer = 1
                    GROUP BY race), --считаем количество платящих игроков в разрезе рассы
        count_race_player AS 
                   (SELECT race,
                          COUNT (id) AS total_players_race
                    FROM fantasy.users u 
                    LEFT JOIN fantasy.race r USING (race_id)
                    GROUP BY race) --считаем количество игроков в разрезе рассы
        SELECT 
        	  pp.race,
        	  pp.payer_player_race,
        	  cp.total_players_race,
        	  round((pp.payer_player_race::REAL/cp.total_players_race::REAL)::NUMERIC ,2)*100 as dol_race_proc
        FROM pay_player_race AS pp
        LEFT JOIN count_race_player AS cp USING (race) --Доля платящих пользователей в разрезе расы персонажа

       
-- Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
		count(transaction_id) AS count_sales, --общее количество покупок
		sum(amount) AS sum_sales, --суммарная стоимость всех покупок
		min(amount) AS min_sales, --минимальная стоимость покупки (907 транзакций с 0)
		max(amount) AS max_sales, --максимальная стоимость покупки
		round(avg(amount)::NUMERIC ,2) AS avg_sales, --средняя стоимость покупки
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_sales, -- медиана стоимости покупки
		round(STDDEV(amount)::NUMERIC,2) AS st_sales--стандартное отклонение стоимости покупки
FROM fantasy.events e
 
-- 2.2: Аномальные нулевые покупки:
WITH 
         nc AS 
                    (SELECT 
                           COUNT (id) AS no_amount
                    FROM fantasy.events e 
                    WHERE amount = 0), --считаем общее количество нулевых покупок 
        ca AS 
                    (SELECT 
                            COUNT (amount) AS total_amount
                     FROM fantasy.events e
                     WHERE amount IS NOT null)--считаем общее количество игроков
        SELECT  
              round((nc.no_amount::REAL / ca.total_amount::REAL)::NUMERIC*100, 3) as dol
        FROM ca AS ca
        CROSS JOIN nc AS nc

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
SELECT
       -- Подсчитаем средние значения:
      category,
      count_player,
      round(avg (total_orders::NUMERIC/count_player),2) AS avg_orders, --среднее количеств заказов по категории на игрока
      round(avg (sum_price::NUMERIC/count_player),2) AS avg_sum_price --средняя суммарная стоимость транзакций на игрока
-- Подзапрос с подсчётом необходимых значений: 
      FROM 
(SELECT
 -- Для каждой группы присвоим свою категорию:
      CASE 
      	  WHEN  payer = 1 
    	  THEN 'Платящий' 
    	  ELSE  'Неплатящий'
      END AS category,
		count (DISTINCT (u.id)) AS count_player, --общее количество игроков
		COUNT (e.transaction_id) AS total_orders, -- общее количество транзакций
        sum (e.amount) AS sum_price -- суммарная стоимость транзакций 
FROM fantasy.users u 
JOIN fantasy.events e USING (id)
GROUP BY  u.payer
) AS podzapros
GROUP BY  category,
		  count_player
		  		        
-- 2.4: Популярные эпические предметы:
	-- общее количество 
WITH oc AS (
        SELECT
       		  count (DISTINCT (e.id)) AS count_users, --количество всех пользователей
       		  count (e.transaction_id) AS count_amount --количество общих продаж за лепестки
		FROM fantasy.items i
		LEFT JOIN fantasy.events e USING (item_code)),
-- общее количество по эпическим предметам
oe AS (
        SELECT 
        	   i.game_items,
        	   COUNT (e.transaction_id) AS count_epic_amount, --абсолютное количество продаж по эпическим предметам
        	   COUNT (DISTINCT (e.id)) count_epic_users --количество игроков по эпическим предметам
        FROM fantasy.events e
	    JOIN fantasy.items i USING (item_code)
	    GROUP BY i.game_items)
SELECT  game_items,  
        (oe.count_epic_amount::real/oc.count_amount::real)*100 AS otn_prod, -- количество относительных продаж в процентах
        (oe.count_epic_users::REAL/oc.count_users::real)*100 AS otn_player --доля игроков, которые покупали предмет в процентах
FROM oc AS oc 
cross JOIN oe AS oe 
WHERE oc.count_amount >0 AND 
      oc.count_users >0
GROUP BY game_items, oe.count_epic_amount, oc.count_amount,
        oe.count_epic_users,oc.count_users
ORDER BY otn_prod DESC


-- ad hoc
-- Зависимость активности игроков от расы персонажа:

-- Общее количество зарегистрированных игроков в разрезе расы
WITH count_player_race AS( 
             SELECT r.race,
                    COUNT (u.id) AS player_race
             FROM  fantasy.users u 
             LEFT JOIN fantasy.race r USING (race_id)
             GROUP BY race),
--считаем общее количество платящих игроков в разрезе рассы
count_pay_race_player AS(
             SELECT r.race,
             		COUNT (DISTINCT (e.id)) AS pay_race_player
             FROM fantasy.events e 
             LEFT JOIN fantasy.users u USING (id)
             LEFT JOIN fantasy.race r USING (race_id)
             WHERE u.payer = 1
             GROUP BY r.race),
--информацию об активности игроков с учётом расы персонажа
activity_race_player AS(
             SELECT race,
             		count (transaction_id) AS sales,
             		round(avg (amount::NUMERIC),2) AS count_sales,
             		sum (amount) AS sum_cost		
             FROM fantasy.users u
             JOIN fantasy.race r USING (race_id)
             JOIN fantasy.events e USING (id)
             WHERE amount >0
             GROUP BY race),
--количествo игроков, которые совершили покупки
count_activ_players AS(
             SELECT race,
                    COUNT (id) AS count_id_transaction
             FROM fantasy.users u
             JOIN fantasy.race r USING (race_id)
             WHERE u.id IN (SELECT id FROM fantasy.events WHERE amount >0)
             GROUP BY race)
SELECT  cpr.race, 
		pay_race_player, --общее количество зарегистрированных игроков
		count_id_transaction, --количество игроков, которые совершают внутриигровые покупки
	    round((count_id_transaction::REAL/player_race::real)::NUMERIC*100,2) AS dkpv,--доля количества игроков, которые совершают внутриигровые покупки, от общего количества
		round((pay_race_player::REAL/count_id_transaction::REAL)::NUMERIC *100,2) AS dolia, --доля платящих игроков от количества игроков, которые совершили покупки
		round((avg (sales)/count_id_transaction::REAL)::NUMERIC,2) AS avg_sales,--среднее количество покупок на одного игрока 
		avg (count_sales) AS avg_cost,--средняя стоимость одной покупки на одного игрока
		round((avg (sum_cost)/count_id_transaction::REAL)::NUMERIC, 2) AS avg_sum_cost--средняя суммарная стоимость всех покупок на одного игрока
FROM count_player_race AS cpr 
full JOIN count_pay_race_player AS cprp ON cpr.race = cprp.race
full JOIN activity_race_player AS arp ON cpr.race = arp.race
FULL JOIN count_activ_players AS cap ON cpr.race = cap.race
GROUP BY cpr.race,
		 pay_race_player,
		 count_id_transaction,
		 cpr.player_race
		
      


  

  