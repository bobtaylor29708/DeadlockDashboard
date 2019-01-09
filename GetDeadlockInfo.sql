/*
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
We grant You a nonexclusive, royalty-free right to use and modify the 
Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; 
(ii) to include a valid copyright notice on Your software product in which the Sample Code is 
embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
Please note: None of the conditions outlined in the disclaimer above will supercede the terms and conditions contained within the Premier Customer Services Description.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		boB Taylor
-- Create date: 1/8/2019
-- Description:	retrieve any xml_deadlock_reports for this instance
-- =============================================
CREATE OR ALTER PROCEDURE sp_GetDeadlockInfo
AS
BEGIN
	-- this algorithm assumes that you have not significantly modified the path for the LOG directory.
	-- i.e. it is at the same path and level as the \data directory. If not, you will have to modify this code
	-- or hardcode the path for each instance when you create the stored procedure.
	SET NOCOUNT ON;

	DECLARE @path nvarchar(255) = '';
	-- First get the default path for DATA
	SET @path = CAST(SERVERPROPERTY('instancedefaultdatapath') AS nvarchar(255));

	-- strip off the data\ and add log\system_health*.xel
	SET @path = REVERSE(SUBSTRING(REVERSE(@path),6,LEN(@path)))+'log\system_health*.xel';

	-- Now retreive any xml_deadlock_reports friom the system health .xel files
	-- NOTE: These are set up to rollover when full so you can wind up missing events
	WITH DeadlockDetails (DeadlockInfo) AS
	(
        SELECT  CAST(C.query('.') AS XML) as DeadlockInfo
        FROM (SELECT
                CAST(event_data AS XML) AS XMLDATA 
            FROM
                sys.fn_xe_file_target_read_file(    
                @path, null, null, null)) a
        CROSS APPLY a.XMLDATA.nodes('/event') as T(C)
        WHERE C.query('.').value('(/event/@name)[1]', 'varchar(255)') = 'xml_deadlock_report'
	)
	-- Now parse the data so we can consume it in Power BI
	SELECT  DeadlockInfo.value('(//event/@timestamp)[1]','datetime') AS [TimeStamp]
		   ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/@id)[1]','varchar(255)') AS [Process ID]
	       ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/@hostname)[1]','varchar(255)') AS [Server Name]
		   ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/@currentdbname)[1]','varchar(255)') AS [Database Name]
		   ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/@isolationlevel)[1]','varchar(255)') AS [Isolation Level]
		   ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/inputbuf)[1]','varchar(max)') AS [Input buffer 1]
		   ,DeadlockInfo.value('(//data/value/deadlock/process-list/process/inputbuf)[2]','varchar(max)') AS [Input buffer 2]
		   ,DeadlockInfo.query('(//data/value/deadlock)[1]') AS [Raw Data]
	FROM DeadlockDetails;
END
GO
