-----------------------------------------------
-- 1 Извлечение скалярного значения
-----------------------------------------------
SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO

-- Scan count 7, logical reads 68255,
-- CPU time = 1669 ms,  elapsed time = 1052 ms.
-- параллель на 6 ядер
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_VALUE(order_details, '$.customer_id') = 5000;


-- Scan count 7, logical reads 68283,
--   CPU time = 3032 ms,  elapsed time = 933 ms.
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_CONTAINS(order_details, 540, '$.items[*].product_id') = 1;

-- 25% набора
-- Scan count 7, logical reads 68283,
-- CPU time = 2517 ms,  elapsed time = 950 ms.
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_VALUE(order_details, '$.shipping_address.city') = N'СПб';

-- Топ-5 городов по количеству заказов
SELECT TOP 5
    JSON_VALUE(order_details, '$.shipping_address.city') AS city,
    COUNT(*) AS order_count
FROM orders
GROUP BY JSON_VALUE(order_details, '$.shipping_address.city')
ORDER BY order_count DESC;

-----------------------------------------------
-- 2 Обновление одного поля (частичное обновление)
-----------------------------------------------

--  относительно orderid:
-- Scan count 0, logical reads 3
-- CPU time = 0 ms,  elapsed time = 0 ms.
-- Поиск одной записи по oderid (PK)
UPDATE dbo.Orders SET order_details.modify('$.status', 'shipped')  -- 2025
WHERE orderid = 1000;

-- Scan count 0, logical reads 3
UPDATE dbo.Orders 
SET order_details = JSON_MODIFY(order_details, '$.status', 'shipped')
WHERE orderid = 1000;


-- Перебор всех документов
-- Table 'Orders'. Scan count 7, 68304, physical reads 127
-- CPU time = 1718 ms,  elapsed time = 925 ms.
UPDATE dbo.Orders SET order_details.modify('$.status', 'shipped') 
WHERE JSON_VALUE(order_details, '$.customer_id') = 5000;


-- Table 'Orders'. Scan count 7, logical reads 68304, ver reads 0
-- CPU time = 1561 ms,  elapsed time = 468 ms.
UPDATE dbo.Orders 
SET order_details = JSON_MODIFY(order_details, '$.status', 'shipped')
WHERE JSON_VALUE(order_details, '$.customer_id') = 5000;


--  Добавить поле "processed": true ко всем заказам из СПб
-- В JSON_MODIFY префикс lax (или его отсутствие) означает, что если путь $.processed не существует, 
-- функция создаст новый ключ. Если использовать strict, то при отсутствии пути будет ошибка.

UPDATE dbo.orders
SET order_details = JSON_MODIFY(order_details, 'lax $.processed', 'true')
WHERE JSON_CONTAINS(order_details, N'СПб', '$.shipping_address.city') = 1;



SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO
