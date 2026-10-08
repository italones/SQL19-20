-- =========================================================================
-- 0. ПОДГОТОВКА: Создаем тестовую базу данных (если её нет)
-- =========================================================================
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'HomeworkDB')
BEGIN
    CREATE DATABASE HomeworkDB;
END
GO

USE HomeworkDB;
GO

-- Создадим простую таблицу для экспериментов, если её нет
IF OBJECT_ID('dbo.Orders', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Orders (
        OrderID INT IDENTITY(1,1) PRIMARY KEY,
        CustomerID INT NOT NULL,
        OrderDate DATETIME NOT NULL,
        Amount MONEY NOT NULL,
        Status VARCHAR(20) NOT NULL
    );
    
    -- Наполним данными для теста
    INSERT INTO dbo.Orders (CustomerID, OrderDate, Amount, Status)
    VALUES 
    (101, '2023-01-01', 100.50, 'Completed'),
    (102, '2023-01-02', 200.00, 'Pending'),
    (103, '2023-01-03', 50.00, 'Completed'),
    (101, '2023-01-04', 300.00, 'Cancelled');
END
GO

-- =========================================================================
-- 1. СОЗДАНИЕ КЛАСТЕРНОГО И НЕКЛАСТЕРНОГО ИНДЕКСА
-- =========================================================================

-- Кластерный индекс: обычно это первичный ключ (создан выше).
-- Если нужно создать явно на другое поле (например, OrderDate):
-- CREATE CLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);

-- Некластерный индекс: создаем по полю CustomerID для ускорения поиска
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID 
ON dbo.Orders (CustomerID);
GO

-- =========================================================================
-- 2. НЕКЛАСТЕРНЫЙ ФИЛЬТРОВАННЫЙ ИНДЕКС (Filtered Index)
-- =========================================================================
-- Создаем индекс только для строк со статусом 'Completed'
CREATE NONCLUSTERED INDEX IX_Orders_Completed_Filtered
ON dbo.Orders (OrderDate)
WHERE Status = 'Completed';
GO

-- =========================================================================
-- 3. КОЛОНОЧНЫЙ ИНДЕКС (Columnstore Index)
-- =========================================================================
-- Создаем некластерный колоночный индекс для аналитики по суммам
CREATE NONCLUSTERED COLUMNSTORE INDEX IX_Orders_Columnstore
ON dbo.Orders (Amount, OrderDate, Status);
GO

-- =========================================================================
-- 4. ФАЙЛОВЫЕ ГРУППЫ (Filegroups)
-- =========================================================================

-- Создаем файловую группу для "медленных" таблиц (исторические данные)
ALTER DATABASE HomeworkDB ADD FILEGROUP FG_SlowData;
GO
ALTER DATABASE HomeworkDB 
ADD FILE (
    NAME = 'HomeworkDB_SlowData', 
    FILENAME = 'C:\SQLData\HomeworkDB_SlowData.ndf', 
    SIZE = 5MB, 
    MAXSIZE = UNLIMITED, 
    FILEGROWTH = 5MB
) TO FILEGROUP FG_SlowData;
GO

-- Создаем файловую группу для "быстрых" таблиц (активные данные)
ALTER DATABASE HomeworkDB ADD FILEGROUP FG_FastData;
GO
ALTER DATABASE HomeworkDB 
ADD FILE (
    NAME = 'HomeworkDB_FastData', 
    FILENAME = 'C:\SQLData\HomeworkDB_FastData.ndf', 
    SIZE = 5MB, 
    MAXSIZE = UNLIMITED, 
    FILEGROWTH = 5MB
) TO FILEGROUP FG_FastData;
GO

-- =========================================================================
-- 5. СОЗДАНИЕ ТАБЛИЦ В НОВЫХ ФАЙЛОВЫХ ГРУППАХ
-- =========================================================================

-- Таблица для медленных данных
CREATE TABLE dbo.SlowArchives (
    ArchiveID INT IDENTITY(1,1) PRIMARY KEY,
    DataContent NVARCHAR(MAX),
    CreatedDate DATETIME DEFAULT GETDATE()
) ON FG_SlowData; -- Явно указываем файловую группу
GO

-- Таблица для быстрых данных
CREATE TABLE dbo.FastLogs (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    LogMessage NVARCHAR(255),
    LogDate DATETIME DEFAULT GETDATE()
) ON FG_FastData; -- Явно указываем файловую группу
GO

PRINT 'Скрипт успешно выполнен!';