-----------------------------------------------
-- 1 Извлечение скалярного значения
-----------------------------------------------

-- Класс операторов GIN по умолчанию для jsonb поддерживает запросы с:
---- операторами существования ключа (?, ?| и ?&), 
---- оператором включения (@>), 
---- операторами соответствия для jsonpath (@? и @@). 


-- Индекс не используется (Parallel Seq Scan on orders)
EXPLAIN
SELECT COUNT(*) FROM public.orders 
WHERE order_details->>'customer_id' = '5000';


-- Запрос с оператором @>
EXPLAIN
SELECT COUNT(*) FROM orders
WHERE order_details @> '{"customer_id": 5000}'::jsonb;

/*
                                      QUERY PLAN
---------------------------------------------------------------------------------------
 Aggregate  (cost=429.35..429.36 rows=1 width=8)
   ->  Bitmap Heap Scan on orders  (cost=39.11..429.10 rows=100 width=0)
         Recheck Cond: (order_details @> '{"customer_id": 5000}'::jsonb)
         ->  Bitmap Index Scan on idx_orders_json  (cost=0.00..39.09 rows=100 width=0)
               Index Cond: (order_details @> '{"customer_id": 5000}'::jsonb)
*/
