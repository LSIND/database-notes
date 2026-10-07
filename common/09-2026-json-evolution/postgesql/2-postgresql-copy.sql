-----------------------------------------------
-- 2 Загрузка\выгрузка данных
-----------------------------------------------

\c ordersdata


-- ВЫГРУЗКА ДАННЫХ
set client_encoding = 'UTF8';
COPY (SELECT order_details FROM public.orders) TO 'C:\out\orders_postgresql.json' WITH (FORMAT TEXT);

-- COPY 1000000
-- Время: 12011,545 мс (00:12,012)

-- ЗАГРУЗКА ДАННЫХ
set client_encoding = 'UTF8';
COPY public.orders(order_details) FROM 'C:\out\orders_mssql.json' WITH (FORMAT TEXT);

-- COPY 1000000
-- Время: 22844,508 мс (00:22,845)