-----------------------------------------------
-- Некоторые другие задачи
-----------------------------------------------


-----------------------------------------------
-- Поиск документов с N элементами массива
-----------------------------------------------

SELECT 
    COUNT(jsonb_array_length(order_details->'items')) AS items_count
FROM public.orders
WHERE jsonb_array_length(order_details->'items') > 4;


-----------------------------------------------
-- Поиск документов с определённым ключом 
-- внутри массива
-----------------------------------------------

SELECT COUNT(*)
FROM public.orders
WHERE jsonb_path_exists(order_details, '$.items[*].discount');


/*                                                       QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual rows=1 loops=1)
   ->  Gather (actual rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate (actual rows=1 loops=3)
               ->  Parallel Seq Scan on orders (actual rows=0 loops=3)
                     Filter: jsonb_path_exists(order_details, '$."items"[*]."discount"'::jsonpath, '{}'::jsonb, false)
                     Rows Removed by Filter: 333333
 Planning Time: 0.304 ms
 Execution Time: 290.711 ms
 */