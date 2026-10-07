# Ускоренное восстановление баз данных MS SQL Server
Скорость процесса восстановления баз данных MS SQL Server напрямую зависит от количества и длительности активных транзакций. Чем больше транзакций и больше их длительность на момент сбоя, тем дольше база данных будет переходить в режим `ONLINE`.  
*В данной статье рассмотрен классический подход к восстановлению баз данных, который используется MS SQL Server и подход ADR, который был внедрен начиная с SQL Server 2019.*  
## Процесс восстановления базы данных ARIES
До версии MS SQL Server 2019 (15.x) восстановление производится согласно классической модели восстановления **ARIES (Algorithm for Recovery and Isolation Exploiting Semantics)** в три этапа:
1. **Анализ (write-ahead logging)**. MS SQL Server выполняет прямой просмотр журнала транзакций от начала последней успешной контрольной точки (или номера LSN самой старой "грязной" страницы) до конца, чтобы определить состояние каждой транзакции на момент остановки SQL Server.
2. **Повтор (REDO)**. MS SQL Server выполняет прямой просмотр журнала транзакций от самой старой незафиксированной транзакции до конца, чтобы перевести базу данных в состояние, которое она имела в момент сбоя через повторное выполнение всех зафиксированных операций.
3. **Откат (UNDO)**. Для каждой транзакции, которая была активна в момент сбоя, MS SQL Server выполняет обратный проход по журналу, отменяя операции, совершенные этой транзакцией.


Итак, время, необходимое для восстановления, пропорционально объему работы, выполненному транзакцией, и времени ее активности. Таким образом, при наличии длительных транзакций (например, больших операций массовой вставки или операций построения индекса для большой таблицы) процесс восстановления базы данных может занимать много времени.  
Кроме того, ядро СУБД *не может усекать журнал транзакций*, если имеются длительные транзакции, так как соответствующие записи журнала необходимы для процессов восстановления и отката. В результате некоторые журналы транзакций становятся очень большими и занимают много места на диске.

### Пример 1 (ARIES):
 Сервер: Microsoft SQL Server 2019 (RTM) - 15.0.2000.5 (X64) - Developer Edition (64-bit) on Windows 10 Enterprise 10.0.   Оборудование: Intel Core i5-8400 2.8 GHz; 8 GB RAM, SSD    
 Клиент: SSMS/sqlcmd. Протокол подключения: Shared memory 

  1. Создание базы данных RecoveryTesting со стандартными настройками:
  ``` sql
USE master
GO

CREATE DATABASE RecoveryTesting;
GO 
-- SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB, LOGSIZE = 8192KB
-- RECOVERY MODEL = FULL
```

2. Массовая вставка данных и ожидание аварийной остановки сервера:  
* сеанс X: Запуск массовой вставки данных в несуществующие таблицы (SELECT INTO) базы данных RecoveryTesting.
* сеанс Y: Открытие другого подключения с SHUTDOWN через 1 минуту, имитирующего аварийное выключение сервера.

```sql
-- X
USE RecoveryTesting;
GO

DROP TABLE IF EXISTS dbo.Table1, dbo.Table1, dbo.Table1;

SELECT s2.* INTO dbo.Table1 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table2 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table3 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
```

``` sql
-- Y
WAITFOR DELAY '00:01:00';
SHUTDOWN WITH NOWAIT;
```
3. Сообщения от сеансов:
* сеанс X: завершается ошибкой 109 (Lvl 20, State 0).   
*A transport-level error has occurred when receiving results from the server. (provider: Shared Memory Provider, error: 0 - The pipe has been ended.)*
* сеанс Y: Сообщение о выключении.  
*Server shut down by NOWAIT request from login. SQL Server is terminating this process.*

4. Поднимаем сервер через SQL Server Configuration manager/net start. Убеждаемся, что сервер запущен. База данных RecoveryTesting находится в режиме `IN RECOVERY`. Ждем окончания восстановления.
5. В текущем логе MS SQL Server находим информацию о восстановлении БД (для простоты отображения оставлено только время и сообщение):

| время             | сообщение                                                                                                                                                                              |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 10:59:03.01   |  Starting up database 'RecoveryTesting'.                                                                                                                                       |
|  10:59:03.22  |  Parallel redo is started for database 'RecoveryTesting' with worker pool size [3].                                                                                            |
|  10:59:07.96  |  Recovery of database 'RecoveryTesting' (19) is 0% complete (approximately 4417 seconds remain). Phase 2 of 3.                                                                 |
|  10:59:55.14  |  Recovery of database 'RecoveryTesting' (19) is 18% complete (approximately 228 seconds remain). Phase 2 of 3.                                                                 |
|  10:59:55.15  |  6 transactions rolled forward in database 'RecoveryTesting' (19:0).                                                                                                           |
|  10:59:55.16  |  Recovery of database 'RecoveryTesting' (19) is 18% complete (approximately 228 seconds remain). Phase 3 of 3.                                                                 |
|  11:00:15.16  |  Recovery of database 'RecoveryTesting' (19) is 68% complete (approximately 33 seconds remain). Phase 3 of 3.                                                                  |
|  11:00:35.16  |  Recovery of database 'RecoveryTesting' (19) is 88% complete (approximately 12 seconds remain). Phase 3 of 3.                                                                  |
|  11:00:46.30  |  1 transactions rolled back in database 'RecoveryTesting' (19:0).                                                                                                              |
|  11:00:46.30  |  Recovery is writing a checkpoint in database 'RecoveryTesting' (19).                                                                                                          |
|  11:00:46.30  |  Recovery completed for database RecoveryTesting (database ID 19) in 104 second(s) (**analysis 4741 ms, redo 47179 ms, undo 51143 ms** [system undo 0 ms, regular undo 51031 ms].) |
|  11:00:46.30  |  Parallel redo is shutdown for database 'RecoveryTesting' with worker pool size [3].                                                                                           |
|  11:00:46.32  |  Recovery is complete.                                                                                                                                                         |

6. Информация о файлах БД:
```sql
USE RecoveryTesting;
GO

SELECT name, type_desc, state_desc, 8*size sizeKb 
FROM sys.database_files;
```
| name                | type_desc | state_desc | sizeKb  |
|---------------------|-----------|------------|---------|
| RecoveryTesting     | ROWS      | ONLINE     | 4005888 |
| RecoveryTesting_log | LOG       | ONLINE     | 4136960 |

7. Удаление базы данных
```sql
USE master
GO

ALTER DATABASE RecoveryTesting 
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

DROP DATABASE RecoveryTesting;
```

## Ускоренное восстановление базы данных (Accelerated database recovery, ADR)
Начиная с версии MS Sql Server 2019 (15.x) предложен новый механизм восстановления БД. ADR обеспечивает быстрое восстановление баз данных благодаря управлению версиями всех физических изменений базы данных и отмене только логических операций. Все транзакции, которые были активны на момент сбоя, помечаются как прерванные, поэтому любые версии, являющиеся результатом этих транзакций, могут быть проигнорированы.  
Фазы восстановления, используемые в ADR, аналогичны ARIES, но используют дополнительные механизмы, в частности **Persisted Version Store (PVS)** и **sLOG**:
1. **Анализ**. Процесс остается таким же, как и в ARIES, но с добавлением восстановления sLOG (stream log). sLOG – это дополнительный поток передачи журнала в памяти, который работает вместе с журналом транзакций. Он усекается по мере фиксации транзакций и позволяет «агрессивно» усекать журнал транзакций, сохраняя только необходимые записи. Кроме того, sLOG сохраняется на диске во время операций с контрольными точками. 
2. **Повтор (REDO)**.
* Повтор из sLOG (от самой старой незафиксированной транзакции до последней контрольной точки). Повтор – это быстрая операция, так как требует обработки всего нескольких записей из sLOG.
* Повтор из журнала транзакций начинается с последней контрольной точки (а не с самой старой незафиксированной транзакции).
3. **Откат (UNDO)**. Этап отмены с ADR завершается почти мгновенно как откат на основе версий на уровне строк (Logical revert). Также происходит отслеживание всех аварийно завершенных транзакций, выполнение отката с помощью PVS (сохранение создаваемых версий строк в самой базе данных, а не в tempdb) для всех пользовательских транзакций и снятие всех блокировок сразу после аварийного завершения транзакции.  

Параллельно вышеперечисленным фазам происходит механизм очистки –  асинхронный процесс, который периодически очищает ненужные версии страниц.


### Пример 2 (ADR):

1. Создание базы данных RecoveryTestingADR со стандартными настройками, но включенной опцией ACCELERATED_DATABASE_RECOVERY
  ``` sql
USE master
GO

CREATE DATABASE RecoveryTestingADR;
GO 
-- SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB, LOGSIZE = 8192KB
-- RECOVERY MODEL = FULL

ALTER DATABASE RecoveryTestingADR
SET ACCELERATED_DATABASE_RECOVERY = ON; -- ADR
GO
```


2. Массовая вставка данных и ожидание аварийной остановки сервера:  
* сеанс X: Запуск массовой вставки данных в несуществующие таблицы (SELECT INTO) базы данных RecoveryTestingADR.
* сеанс Y: Открытие другого подключения с SHUTDOWN через 1 минуту, имитирующего аварийное выключение сервера.

```sql
-- X
USE RecoveryTestingADR;
GO

DROP TABLE IF EXISTS dbo.Table1, dbo.Table1, dbo.Table1;

SELECT s2.* INTO dbo.Table1 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table2 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table3 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
```

``` sql
-- Y
WAITFOR DELAY '00:01:00';
SHUTDOWN WITH NOWAIT;
```
3. Сообщения от сеансов:
* сеанс X: завершается ошибкой 596 (Lvl 21, State 1) и ошибкой 0 (Lvl 20).   
*Cannot continue the execution because the session is in the kill state.
A severe error occurred on the current command. The results, if any, should be discarded.*
* сеанс Y: Сообщение о выключении.  
*Server shut down by NOWAIT request from login. SQL Server is terminating this process.*

4. Поднимаем сервер через SQL Server Configuration manager/net start. Убеждаемся, что сервер запущен. База данных RecoveryTestingADR находится в режиме `IN RECOVERY`. Ждем окончания восстановления.
5. В текущем логе MS SQL Server находим информацию о восстановлении БД:

| время        | сообщение                                                                                                                                                              |
|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  12:13:56.44 |   Starting up database 'RecoveryTestingADR'.                                                                                                                              |
|  12:13:56.65 |   Parallel redo is started for database 'RecoveryTestingADR' with worker pool size [3].                                                                                   |
|  12:13:58.92 |   Recovery of database 'RecoveryTestingADR' (19) is 0% complete (approximately 431 seconds remain). Phase 2 of 3.                                                         |
|  12:14:01.12 |   Recovery of database 'RecoveryTestingADR' (19) is 2% complete (approximately 170 seconds remain). Phase 2 of 3.                                                         |
|  12:14:01.12 |   3 transactions rolled forward in database 'RecoveryTestingADR' (19:0).                                                                                                  |
|  12:14:01.13 |   Recovery of database 'RecoveryTestingADR' (19) is 2% complete (approximately 170 seconds remain). Phase 3 of 3.                                                         |
|  12:14:01.13 |   [DbId:19] ADR enabled for the database.                                                                                                                              |
|  12:14:01.17 |   1 transactions rolled back in database 'RecoveryTestingADR' (19:0).                                                                                                     |
|  12:14:01.17 |   Recovery is writing a checkpoint in database 'RecoveryTestingADR' (19).                                                                                                 |
|  12:14:01.33 |   Recovery completed for database RecoveryTestingADR (database ID 19) in 5 second(s) (**analysis 2265 ms, redo 2201 ms, undo 46 ms** [system undo 0 ms, regular undo 0 ms].)  |
|  12:14:01.33 |   ADR enabled for the database.                                                                                                                                        |
|  12:14:01.34 |   Parallel redo is shutdown for database 'RecoveryTestingADR' with worker pool size [3].                                                                                  |
|  12:14:01.85 |   Recovery is complete.                                                                                                                                                |


6. Информация о файлах БД:
```sql
USE RecoveryTestingADR;
GO

SELECT name, type_desc, state_desc, 8*size sizeKb 
FROM sys.database_files;
```
| name                   | type_desc | state_desc | sizeKb  |
|------------------------|-----------|------------|---------|
| RecoveryTestingADR     | ROWS      | ONLINE     | 4071424 |
| RecoveryTestingADR_log | LOG       | ONLINE     | 729088  |

7. Удаление базы данных
```sql
USE master
GO

ALTER DATABASE RecoveryTestingADR 
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

DROP DATABASE RecoveryTestingADR;
```

## Сравнение тестовых прогонов

### 1. Время выполнения фаз восстановления (усреднённо)
* ARIES: analysis 4741 ms, redo 47179 ms, undo 51143 ms   
* ADR: analysis 2265 ms, redo 2201 ms, undo 46 ms

``` mermaid
---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#afafec, #74a888'
---
xychart
title "Время выполнения фаз восстановления"
x-axis  ["Analysis", "REDO", "UNDO"]
y-axis "Время, мс" 0 --> 53000

%% Blue bar
bar "ARIES" [4700,47000,51000]
%% Green bar
bar "ADR" [2200,2200,50]
```
### 2. Размер файлов БД и журнала после восстановления (усреднённо)

``` mermaid
---
config:
  themeVariables:
    xyChart:
      showDataLabel: true
      plotColorPalette: '#afafec, #74a888'
      
---
xychart
title "Размер файлов БД и журнала после восстановления"
x-axis ["DB File", "DB File adr", "Log", "Log Adr"]
y-axis "Размер файла, Мб" 100 --> 4500

%% Blue bar
%% Green bar
bar "ARIES" [3900, -1, 4000, -1]
bar "ADR" [-1, 4000, -1, 700]

```
### Выводы по тестовым прогонам:
1. Скорость восстановления БД увеличилась в 20 раз: с 104 секунд ARIES до 5 сек ADR;
2. Агрессивное усечение журнала транзакций привело к сокращению размера файла журнала в 5.5 раз;
3. Файл базы данных с ADR увеличился на 9-10% из-за версионности.


## Итоги
* Подход ADR обеспечивает быстрое восстановление БД благодаря управлению версиями всех физических изменений базы данных и отмене только логических операций, которая может производиться почти мгновенно. Все транзакции, которые были активны на момент сбоя, помечаются как прерванные, поэтому любые версии, являющиеся результатом этих транзакций, могут быть проигнорированы.  
* Процесс длится короткое время из-за того, что не приходится проверять журнал от начала самой старой активной транзакции. При использовании ADR журнал транзакций обрабатывается только от последней успешной контрольной точки (или регистрационного номера транзакции в журнале (LSN), принадлежащего самой старой "грязной" странице). В результате длительные транзакции не влияют на время восстановления.  
* Уменьшается место, которое требуется для журнала транзакций, так как больше не нужно обрабатывать журнал для всей транзакции. В результате журнал транзакций может агрессивно усекаться при наличии контрольных точек и резервных копий.

### Улучшения ADR в MS SQL Server 2022
В MS SQL Server 2019 (15.x) процесс очистки в ADR выполняется единственным потоком. Начиная с MS SQL Server 2022 (16.x), данный процесс использует многопоточную очистку версий - Multi-Threaded Version Cleanup (MTVC), что позволяет параллельно очищать несколько баз данных одного экземпляра SQL Server.
