-----------------------------------------------
-- 1 Извлечение скалярного значения
-----------------------------------------------
USE OrdersData;
GO


SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO

-- Индекс работает только с функцией JSON_CONTAINS
--
-- Table 'Orders'. Scan count 0, logical reads 4976, 
-- Table 'json_index_1221579390_1216000'. Scan count 1, logical reads 7, 
--   CPU time = 0 ms,  elapsed time = 25 ms.
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_CONTAINS(order_details, 540, '$.items[*].product_id') = 1;

-- Table 'json_index_1221579390_1216000'. Scan count 1, logical reads 4,
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_CONTAINS(order_details, 5000, '$.customer_id') = 1;

-- Индекс не используется
-- Table 'Orders'. Scan count 7, logical reads 68239,
SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_VALUE(order_details, '$.customer_id') = 5000;


-- !! SQL Server должен сравнить значение N'СПб' с значением внутри sql_variant. 
-- Поскольку колонка sql_value не имеет единой коллации, оптимизатор не может гарантировать, 
-- что сравнение будет корректным при использовании индекса. 
-- В результате он выбирает безопасный путь — полное сканирование.

SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_CONTAINS(order_details, N'СПб' , '$.shipping_address.city') = 1;

SELECT COUNT(*) 
FROM dbo.orders 
WHERE JSON_CONTAINS(order_details, 
N'СПб' COLLATE Latin1_General_100_BIN2_UTF8, '$.shipping_address.city') = 1;





-----------------------------------------------
-- 2 Обновление одного поля (частичное обновление)
-----------------------------------------------

-- Поиск одной записи по orderid (PK)
-- Table 'json_index_1221579390_1216000'. Scan count 1, logical reads 333
-- Table 'Worktable'. Scan count 5, logical reads 113,
-- Table 'Orders'. Scan count 0, logical reads 3,
UPDATE dbo.Orders SET order_details.modify('$.status', 'shipped')  -- 2025
WHERE orderid = 1000;

-- Table 'json_index_1221579390_1216000'. Scan count 1, logical reads 333,
-- Table 'Worktable'. Scan count 5, logical reads 113,
-- Table 'Orders'. Scan count 0, logical reads 3,
UPDATE dbo.Orders 
SET order_details = JSON_MODIFY(order_details, '$.status', 'shipped')
WHERE orderid = 1000;


-- Поиск и обновление с JSON_VALUE
-- Table 'json_index_1221579390_1216000'. Scan count 8, logical reads 3066,
-- Table 'Worktable'. Scan count 6, logical reads 1048
-- Table 'Orders'. Scan count 0, logical reads 42, 
UPDATE dbo.Orders 
SET order_details.modify('$.status', 'shipped')
WHERE JSON_CONTAINS(order_details, 5000, '$.customer_id') = 1;



SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO
