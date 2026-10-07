-----------------------------------------------
-- Некоторые другие задачи
-----------------------------------------------


-----------------------------------------------
-- Поиск документов с N элементами массива
-----------------------------------------------

SET NOCOUNT ON;

-- Временная таблица для накопления результата
IF OBJECT_ID('tempdb..#ItemsOver4') IS NOT NULL
    DROP TABLE #ItemsOver4;

CREATE TABLE #ItemsOver4 (
    orderid INT PRIMARY KEY,
    items_count INT
);

DECLARE 
    @batch_size INT = 100000,
    @min_id INT,
    @max_id INT,
    @current_id INT;

-- границы диапазона orderid
SELECT 
    @min_id = MIN(orderid),
    @max_id = MAX(orderid)
FROM dbo.Orders;

SET @current_id = @min_id;

-- Цикл по батчам
WHILE @current_id <= @max_id
BEGIN
    INSERT INTO #ItemsOver4 (orderid, items_count)
    SELECT 
        o.orderid,
        j.items_count
    FROM (
        SELECT TOP (@batch_size) orderid, order_details
        FROM dbo.Orders
        WHERE orderid >= @current_id
        ORDER BY orderid
    ) AS o
    CROSS APPLY (
        SELECT COUNT(*) AS items_count
        FROM OPENJSON(o.order_details, '$.items')
    ) AS j
    WHERE j.items_count > 4;

    -- Переходим к следующему диапазону
    SELECT @current_id = MAX(orderid) + 1
    FROM (
        SELECT TOP (@batch_size) orderid
        FROM dbo.Orders
        WHERE orderid >= @current_id
        ORDER BY orderid
    ) AS batch;

    -- Если строк больше нет — выходим
    IF @current_id IS NULL
        BREAK;
END;

-- Итоговый результат
SELECT orderid, items_count
FROM #ItemsOver4
ORDER BY orderid;

-- количество
SELECT COUNT(*) AS documents_with_more_than_4_items FROM #ItemsOver4;

DROP TABLE #ItemsOver4;


SET STATISTICS IO OFF;
GO
SET STATISTICS TIME OFF;
GO


-----------------------------------------------
-- Поиск документов с определённым ключом 
-- внутри массива
-----------------------------------------------


SELECT COUNT(*)
FROM dbo.orders
WHERE JSON_PATH_EXISTS(order_details, '$.items[*].discount') = 1;





