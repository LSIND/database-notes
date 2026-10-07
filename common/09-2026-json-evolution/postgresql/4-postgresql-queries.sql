-----------------------------------------------
-- 1 Извлечение скалярного значения
-----------------------------------------------


EXPLAIN
SELECT COUNT(*) FROM public.orders 
WHERE order_details->>'customer_id' = '5000';


SELECT COUNT(*)  -- SQL/JSON Path с wildcard
FROM orders 
WHERE jsonb_path_exists(order_details, '$.items[*].product_id ? (@ == 540)');

UPDATE public.orders
SET order_details = jsonb_set(order_details, '{status}', '"shipped"')
WHERE order_details->>'customer_id' = '5000';



-- заказы, где сумма total > 1005
SELECT COUNT(*) FROM public.orders
WHERE order_details @? '$.total ? (@ > 1005)';

-- заказы, где есть товар с ценой выше 190
SELECT COUNT(*) FROM orders
WHERE order_details @? '$.items[*].price ? (@ > 190)';

-----------------------------------------------

EXPLAIN
SELECT COUNT(*) FROM public.orders
WHERE order_details @> '{"customer_id": 5000}'::jsonb;


SELECT COUNT(*) 
FROM orders 
WHERE order_details @> '{"items": [{"product_id": 540}]}'::jsonb;

SELECT COUNT(*) 
FROM orders 
WHERE order_details @> '{"shipping_address": {"city": "СПб"}}'::jsonb;


-- заказы, где статус = "shipped" И total > 1000
SELECT COUNT(*) FROM orders
WHERE order_details @@ '$.status == "shipped" && $.total > 1000';


-----------------------------------------------
-- 2 Обновления 
-----------------------------------------------

UPDATE public.orders
SET order_details = jsonb_set(order_details, '{status}', '"shipped"')
WHERE order_details @> '{"customer_id": 5000}'::jsonb;


--  Добавить поле "processed": true ко всем заказам из СПб

UPDATE public.orders
SET order_details = jsonb_set(order_details, '{processed}', 'true'::jsonb)
WHERE order_details @> '{"shipping_address": {"city": "СПб"}}'::jsonb;

