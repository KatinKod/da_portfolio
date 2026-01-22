-- Анализ рынка недвижимости Санкт-Петербурга


-- Фильтр аномальных значений и категоризация запросов
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Объявления без выбросов:
anomaly AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT id FROM filtered_id)
),
-- Предварительно вычисляем категории:
categorized_data AS (
    SELECT 
        CASE 
            WHEN c.city = 'Санкт-Петербург'
                THEN 'Санкт-Петербург' 
                ELSE 'Лен.Обл'
        END AS region,
        CASE 
            WHEN ad.days_exposition BETWEEN 1 AND 30
                THEN 'До месяца' 
            WHEN ad.days_exposition BETWEEN 31 AND 90
                THEN 'До 3 месяцев' 
            WHEN ad.days_exposition BETWEEN 91 AND 180
                THEN 'До полугода' 
            ELSE 'Больше полугода'
        END AS activity,
        a.id,
        ad.last_price,
        a.total_area,
        a.floor,
        a.balcony,
        a.rooms,
        a.kitchen_area,
        a.ceiling_height
    FROM anomaly a
    JOIN real_estate.advertisement ad ON a.id = ad.id
    JOIN real_estate.city c ON a.city_id = c.city_id
    JOIN real_estate."type" t ON a.type_id = t.type_id
    WHERE ad.days_exposition IS NOT NULL 
        AND t.type = 'город'
)
-- Финальная агрегация:
SELECT 
    region,
    activity,
    COUNT(DISTINCT id) AS count_advertisment,
    ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_kvm,
    ROUND(AVG(total_area::NUMERIC), 2) AS avg_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS floor_mediana,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_mediana,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_mediana,
    MAX(kitchen_area) AS max_kitchen,
    MAX(ceiling_height) AS max_ceiling
FROM categorized_data
GROUP BY region, activity
ORDER BY 
    region,
    CASE activity
        WHEN 'До месяца' THEN 1
        WHEN 'До 3 месяцев' THEN 2
        WHEN 'До полугода' THEN 3
        ELSE 4
    END;
    
-- Сезонность объявлений - данные на дату публикации объявления
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Объявления без выбросов:
anomaly AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT id FROM filtered_id)
),
-- Извлечение по месяцам подачи объявлений:
begin_publications AS (
    SELECT 
        EXTRACT(MONTH FROM adv.first_day_exposition)::INTEGER AS begin_public_month,
        COUNT(adv.id) AS count_public,
        ROUND(AVG(adv.last_price::NUMERIC / f.total_area::NUMERIC), 2) AS avg_price_kvm,
        ROUND(AVG(f.total_area::NUMERIC), 2) AS avg_area
    FROM real_estate.advertisement adv
    JOIN anomaly f ON adv.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate."type" t ON f.type_id = t.type_id
    WHERE EXTRACT(YEAR FROM adv.first_day_exposition) BETWEEN 2015 AND 2018
        AND t.type = 'город'
    GROUP BY EXTRACT(MONTH FROM adv.first_day_exposition)
)
-- Финальный результат:
SELECT 
    RANK() OVER (ORDER BY count_public DESC) AS rank_begin_publ,
    CASE begin_public_month
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS month_begin,
    count_public,
    avg_price_kvm,
    avg_area
FROM begin_publications
ORDER BY rank_begin_publ;

-- Данные на дату окончания публикации объявления 
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Объявления без выбросов:
anomaly AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT id FROM filtered_id)
),
-- Извлечение по месяцам окончания объявлений:
end_publications AS (
    SELECT 
        EXTRACT(MONTH FROM (a.first_day_exposition + (a.days_exposition || ' days')::INTERVAL))::INTEGER AS end_public_month,
        COUNT(a.id) AS end_count_public,
        ROUND(AVG(a.last_price::NUMERIC / f.total_area::NUMERIC), 2) AS end_avg_price_kvm,
        ROUND(AVG(f.total_area::NUMERIC), 2) AS end_avg_area
    FROM real_estate.advertisement a
    JOIN anomaly f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate."type" t ON f.type_id = t.type_id
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND t.type = 'город'
        AND a.days_exposition IS NOT NULL
        AND (a.first_day_exposition + (a.days_exposition || ' days')::INTERVAL) IS NOT NULL
    GROUP BY EXTRACT(MONTH FROM (a.first_day_exposition + (a.days_exposition || ' days')::INTERVAL))
)
-- Финальный результат:
SELECT 
    RANK() OVER (ORDER BY end_count_public DESC) AS rank_end_publ,
    CASE end_public_month
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS month_end,
    end_count_public,
    end_avg_price_kvm,
    end_avg_area
FROM end_publications
WHERE end_public_month IS NOT NULL
ORDER BY rank_end_publ;

-- Анализ рынка недвижимости Ленобласти

-- Фильтрация аномальных значений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Объявления без выбросов:
anomaly AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT id FROM filtered_id)
)
-- Основной запрос:
SELECT 
    c.city, -- города в ленобласти
    COUNT(a.id) AS count_advertisment, -- количество объявлений
    ROUND(AVG(adv.last_price::NUMERIC / a.total_area::NUMERIC), 2) AS avg_price_kvm, -- средняя стоимость объявлений за кв.м
    ROUND(AVG(a.total_area::NUMERIC), 2) AS avg_area, -- средняя площадь квартир
    ROUND(
        COUNT(CASE WHEN adv.days_exposition IS NOT NULL THEN 1 END)::NUMERIC / 
        COUNT(a.id) * 100, 
        2
    ) AS dol_public, -- доля проданной недвижимости в процентах
    ROUND(
        AVG(CASE 
            WHEN adv.days_exposition IS NOT NULL 
            THEN adv.days_exposition::NUMERIC 
            ELSE NULL 
        END), 
        2
    ) AS avg_sale_days -- среднее время продажи недвижимости в днях
FROM anomaly a
LEFT JOIN real_estate.advertisement adv ON a.id = adv.id
LEFT JOIN real_estate.city c ON a.city_id = c.city_id
WHERE c.city != 'Санкт-Петербург'
GROUP BY c.city
ORDER BY COUNT(a.id) DESC

LIMIT 15;
