
-----------------------------------------------
-- 3 JSON Индекс
-----------------------------------------------

USE OrdersData;
GO

CREATE JSON INDEX idx_orders_json 
ON dbo.orders (order_details)
FOR ('$.items', '$.shipping_address', '$.customer_id', '$.total', '$.status')
WITH (OPTIMIZE_FOR_ARRAY_SEARCH = ON, DATA_COMPRESSION = PAGE);

-- на одну JSON-колонку можно создать только один JSON-индекс
-- включим несколько путей в один JSON-индекс, если они не перекрываются.

SELECT  *
FROM sys.json_indexes 
WHERE object_id = OBJECT_ID('dbo.orders');

SELECT * FROM sys.json_index_paths
WHERE object_id = OBJECT_ID('dbo.orders');
/* $.items, $.shipping_address, $.customer_id, $.total, $.status */


-----------------------------------------------
-----------------------------------------------
-- Внутренняя таблица json-индекса: 
------ json_index_object_name	        object_id	type_desc	    parent_table
------ json_index_1221579390_1216000	1541580530	INTERNAL_TABLE	Orders

SELECT 
    ao.name AS json_index_object_name,
    ao.object_id,
    ao.type_desc,
    OBJECT_NAME(ao.parent_object_id) AS parent_table
FROM sys.all_objects ao
WHERE OBJECT_NAME(ao.parent_object_id) = N'orders'
  AND ao.name LIKE N'json_index_%';


-- Размер индекса:
-- Ищем внутреннюю таблицу в sys.dm_db_partition_stats и all_objects
-- Средний размер такого индекса - 600 Мб
SELECT 
    ao.name AS json_index_object_name,
    ao.object_id,
    ps.index_id,
    ps.partition_number,
    ps.row_count,
    ps.used_page_count,
    ps.used_page_count * 8.0 / 1024 AS size_mb
FROM sys.all_objects ao WITH (NOLOCK)
LEFT OUTER JOIN sys.dm_db_partition_stats ps WITH (NOLOCK) 
    ON ao.object_id = ps.object_id
WHERE OBJECT_NAME(ao.parent_object_id) = N'orders'
  AND ao.name LIKE N'json_index_%';

EXEC sys.sp_spaceused  'dbo.orders'; -- 625672 KB


-----------------------------------------------
-- !!! Изучить структуру JSON-индекса можно только в режиме подключения DAC
-----------------------------------------------


EXEC sys.sp_help 'sys.json_index_1221579390_1216000';

/*
Column_name	        Type	    Computed	Length	Prec    Scale	Nullable	Collation
json_path	        varchar	    no	        630	     	     	    no          Latin1_General_100_BIN2_UTF8	        
json_array_index	varbinary	no	        512	     	     	    yes	
sql_value	        sql_variant	no	        8016	     	     	yes	
status	            smallint	no	        2	    5    	0    	yes	
full_json_path	    varchar	    no	        8000	     	     	yes         Latin1_General_100_BIN2_UTF8	
full_json_value	    nvarchar	no	        -1	     	     	    yes         Cyrillic_General_CI_AS	
posting_1	        int	        no	        4	    10   	0    	no	
*/

---- sql_value (тип sql_variant) хранит значение
---- json_array_index: номер элемента в массиве (если массив)
---- posting_1 - связь с первичным ключом таблицы orders (может содержать столбцы posting_2, .. posting_n)
---- данные хранятся в упорядоченном виде по json_path и sql_value


-- Уникальные значения в json_path: 
------ customer_id, 
------ items#.price, items#.product_id, items#.quantity, 
------ shipping_address.city, shipping_address.country, shipping_address.street
------ status, total
SELECT DISTINCT json_path
FROM sys.json_index_1221579390_1216000;


-- Всего записей в таблице:
SELECT COUNT(*)
FROM sys.json_index_1221579390_1216000; -- 14 712 000
-- Можно приблизительно рассчитать по путям: 
------ 6 json_path (каждый повторяется миллион раз)
------ в среднем 3 элемента в массиве items#, у каждого из которых 3 ключа (каждый повторяется миллион раз)
------ 6 000 000 + 9 000 000 ~ 15 000 000 записей


-- Просмотреть связь индекса и таблицы:
SELECT TOP(5) o.orderid, o.order_details, ind.json_path, ind.json_array_index,
ind.sql_value, ind.status, ind.posting_1
FROM dbo.Orders as o
INNER JOIN sys.json_index_1221579390_1216000 as ind
ON ind.posting_1 = o.orderid 
WHERE json_path = 'items#.price';

/*
orderid	order_details	                json_path	    json_array_index	sql_value	status	posting_1
496679	{"items":[{"price":5.02,"qua..	items#.price	0x00000000	        5.02	    0		496679
488820	{"items":[{"price":5.02,"qua..	items#.price	0x00000000	        5.02	    0		488820
490490	{"items":[{"price":5.02,"qua..	items#.price	0x00000000	        5.02	    0		490490
488805	{"items":[{"price":5.02,"qua..	items#.price	0x00000000	        5.02	    0		488805
496694	{"items":[{"price":5.02,"qua..	items#.price	0x00000000	        5.02	    0	    496694
*/


-----------------------------------------------
-- Перестроение индекса только с полной блокировкой:

ALTER INDEX [idx_orders_json] 
ON [Orders] 
REBUILD WITH (ONLINE = ON); -- error


ALTER INDEX [idx_orders_json] 
ON [Orders] REBUILD ;

-- Информация об индексе:
select index_id, index_type_desc, index_level, avg_fragmentation_in_percent, page_count, record_count, avg_page_space_used_in_percent
from sys.dm_db_index_physical_stats(DB_ID(N'OrdersData'), OBJECT_ID(N'dbo.Orders'), NULL, NULL , 'DETAILED');

/*
index_id	index_type_desc	index_level	avg_fragmentation_in_percent	page_count	record_count	avg_page_space_used_in_percent
1	        CLUSTERED INDEX	0	        0,01	                        67043	    1000000	        96,7354830738819
1	        CLUSTERED INDEX	1	        0	                            248	        67043	        43,3945021003212
1	        CLUSTERED INDEX	2	        0	                            1	        248	            39,8072646404744
1216000	    JSON INDEX	    0	        0,766441404318444	            24268	    14712000	    99,5486780331109
1216000	    JSON INDEX	    1	        48,3766233766234	            308	        24268	        51,5185322461082
1216000	    JSON INDEX	    2	        100	                            5	        308	            41,5764764022733
1216000	    JSON INDEX	    3	        0	                            1	        5	            3,52112676056338
*/

-----------------------------------------------
-----------------------------------------------
-- Индекс можно отключить или удалить:

ALTER INDEX [idx_orders_json] ON [Orders] DISABLE;

DROP INDEX [idx_orders_json] ON [dbo].[Orders];