
-----------------------------------------------
-- 3 GIN Индекс
-----------------------------------------------

CREATE INDEX idx_orders_json
ON public.orders USING GIN (order_details);

-- Размер индекса
SELECT pg_size_pretty(pg_relation_size('idx_orders_json')); -- 148 Мб


-----------------------------------------------
-- Перестроение индекса доступно в режиме ONLINE:

REINDEX INDEX CONCURRENTLY idx_orders_json;



