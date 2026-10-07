-----------------------------------------------
-- Подготовка теста
-----------------------------------------------

CREATE DATABASE ordersdata;

\c ordersdata


CREATE TABLE public.orders (
    orderid INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_details JSONB NOT NULL
);


-----------------------------------------------
-- записываем 1000 раз блоками по 1000 записей
-- ~ 30s
-----------------------------------------------

DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..1000 LOOP
        INSERT INTO public.orders (order_details)
        SELECT jsonb_build_object(
            'customer_id', (random() * 100000 + 1)::INT,
            'order_date', to_char(
                now() - (random() * interval '365 days'),
                'YYYY-MM-DD"T"HH24:MI:SS.USOF'
            ),
            'status', (ARRAY['pending','shipped','delivered','cancelled'])[floor(random()*4)+1],
            'total', round((random() * 1000 + 10)::numeric, 2),
            'items', COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'product_id', (random() * 10000 + 1)::INT,
                            'quantity',   (random() * 5 + 1)::INT,
                            'price',      round((random() * 200 + 5)::numeric, 2)
                        )
                    )
                    FROM generate_series(1, floor(random()*5 + 1)::INT)
                ),
                '[]'::jsonb
            ),
            'shipping_address', jsonb_build_object(
                'street', 'ул. ' ||
                    (ARRAY['Ленина','Пушкина','Гагарина','Мира'])[floor(random()*4)+1]
                    || ' ' || (floor(random()*100)+1)::TEXT,
                'city', (ARRAY['Москва','СПб','Новосибирск','Екатеринбург'])[floor(random()*4)+1],
                'country', 'Россия'
            )
        )
        FROM generate_series(1, 1000);
    END LOOP;
END $$;


-----------------------------------------------
-- 1 Размер данных
-----------------------------------------------

-- Размер таблицы (TOAST таблица пуста, каждая версия строки попадает на одну страницу)
SELECT pg_size_pretty(pg_table_size('public.orders')); --  536 MB

-- Размер индекса PK
SELECT pg_size_pretty(pg_indexes_size('public.orders')); --  21 MB


-----------------------------------------------
-- 2 Загрузка\выгрузка данных
-----------------------------------------------

-- ВЫГРУЗКА ДАННЫХ
--  set client_encoding = 'UTF8';
--  COPY (SELECT order_details FROM public.orders) TO 'C:\out\orders_postgresql.json' WITH (FORMAT TEXT);

-- ЗАГРУЗКА ДАННЫХ
--  set client_encoding = 'UTF8';
--  COPY public.orders(order_details) FROM 'C:\out\orders_mssql.json' WITH (FORMAT TEXT);


-----------------------------------------------
-- Пример сгенерированного документа
-----------------------------------------------

/*
 {                                                 +
     "items": [                                    +
         {                                         +
             "price": 95.16,                       +
             "quantity": 5,                        +
             "product_id": 2218                    +
         },                                        +
         {                                         +
             "price": 192.50,                      +
             "quantity": 6,                        +
             "product_id": 64                      +
         }                                         +
     ],                                            +
     "total": 93.38,                               +
     "status": "delivered",                        +
     "order_date": "2026-02-23T01:55:52.488700+03",+
     "customer_id": 29688,                         +
     "shipping_address": {                         +
         "city": "СПб",                            +
         "street": "ул. Ленина 53",                +
         "country": "Россия"                       +
     }                                             +
 }
 */

-----------------------------------------------
-----------------------------------------------


