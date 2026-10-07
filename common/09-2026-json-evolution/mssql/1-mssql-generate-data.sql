-----------------------------------------------
-- Подготовка теста
-----------------------------------------------

CREATE DATABASE OrdersData;
GO

ALTER DATABASE OrdersData
SET RECOVERY Simple;

USE OrdersData;
GO

CREATE TABLE dbo.Orders
(
    orderid INT IDENTITY PRIMARY KEY,
    order_details json NOT NULL  -- нативный тип, а не NVARCHAR(MAX)
);


-----------------------------------------------
-- записываем 1000 раз блоками по 1000 записей
-- ~ 15min
-----------------------------------------------

/*SET STATISTICS IO ON;
GO
SET STATISTICS TIME ON;
GO*/
-- в среднем каждый блок записывался 90мс
-- итого 1.5 минуты

WITH RandomData AS (
    SELECT 
        ABS(CHECKSUM(NEWID())) AS rnd1,
        ABS(CHECKSUM(NEWID())) AS rnd2,
        ABS(CHECKSUM(NEWID())) AS rnd3
    FROM sys.objects AS o1
    CROSS JOIN sys.objects AS o2
    CROSS JOIN sys.objects AS o3
    CROSS JOIN sys.objects AS o4
)
INSERT INTO dbo.Orders (order_details)
SELECT TOP 1000    -- 
    JSON_OBJECT(
        'customer_id': CAST(ABS(CHECKSUM(NEWID())) % 100000 + 1 AS INT),
        'order_date': FORMAT(
            DATEADD(
                nanosecond, 
                ABS(CHECKSUM(NEWID())) % 10000000,
                DATEADD(
                    second, 
                    -ABS(CHECKSUM(NEWID())) % 31536000,
                    SYSDATETIMEOFFSET()
                )
            ),
            'yyyy-MM-ddTHH:mm:ss.fffffffzzz'
        ),
        'status': CASE ABS(CHECKSUM(NEWID())) % 4
            WHEN 0 THEN 'pending'
            WHEN 1 THEN 'shipped'
            WHEN 2 THEN 'delivered'
            ELSE 'cancelled'
        END,
        'total': CAST(ROUND((RAND(CHECKSUM(NEWID())) * 1000 + 10), 2) AS DECIMAL(10,2)),
        'items': CAST(JSON_QUERY((
            SELECT 
                CAST(ABS(CHECKSUM(r.rnd1, nums.n)) % 10000 + 1 AS INT) AS product_id,
                CAST(ABS(CHECKSUM(r.rnd2, nums.n)) % 5 + 1 AS INT) AS quantity,
                CAST(ROUND((RAND(CHECKSUM(r.rnd3, nums.n)) * 200 + 5), 2) AS DECIMAL(10,2)) AS price
            FROM (VALUES (1),(2),(3),(4),(5)) AS nums(n)
            WHERE n <= CAST(ABS(CHECKSUM(r.rnd1, nums.n)) % 5 + 1 AS INT)
            FOR JSON PATH) 
        ) as json),
        'shipping_address': JSON_OBJECT(
            'street': 'ул. ' + 
                CASE ABS(CHECKSUM(NEWID())) % 4
                    WHEN 0 THEN 'Ленина'
                    WHEN 1 THEN 'Пушкина'
                    WHEN 2 THEN 'Гагарина'
                    ELSE 'Мира'
                END + ' ' + CAST(ABS(CHECKSUM(NEWID())) % 100 + 1 AS VARCHAR),
            'city': CASE ABS(CHECKSUM(NEWID())) % 4
                WHEN 0 THEN 'Москва'
                WHEN 1 THEN 'СПб'
                WHEN 2 THEN 'Новосибирск'
                ELSE 'Екатеринбург'
            END,
            'country': 'Россия' RETURNING JSON
        ) RETURNING JSON
    ) AS datajson
FROM RandomData r
CROSS JOIN sys.objects AS o1
CROSS JOIN sys.objects AS o2
CROSS JOIN sys.objects AS o3
CROSS JOIN sys.objects AS o4;
GO 1000

/*
SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO*/


-----------------------------------------------
-- 1 Размер данных
-----------------------------------------------

-- Размер таблицы (in-row данные, LOB отсутствуют)
-- Кластерный индекс PK
SELECT 
    SUM(used_page_count) * 8 / 1024.0 AS used_mb
FROM sys.dm_db_partition_stats
WHERE object_id = OBJECT_ID('dbo.Orders'); -- 529.81mb


-----------------------------------------------
-- Пример сгенерированного документа
-----------------------------------------------

/*{
  "customer_id": 96876,
  "order_date": "2026-04-06T11:23:13.2208326+03:00",
  "status": "cancelled",
  "total": 992.85,
  "items": [
    {
      "product_id": 9581,
      "quantity": 2,
      "price": 35.65
    },
    {
      "product_id": 9578,
      "quantity": 3,
      "price": 35.66
    },
    {
      "product_id": 9579,
      "quantity": 4,
      "price": 35.66
    },
    {
      "product_id": 9584,
      "quantity": 2,
      "price": 35.67
    },
    {
      "product_id": 9585,
      "quantity": 3,
      "price": 35.67
    }
  ],
  "shipping_address": {
    "street": "ул. Пушкина 73",
    "city": "Екатеринбург",
    "country": "Россия"
  }
}*/

-----------------------------------------------
-----------------------------------------------


