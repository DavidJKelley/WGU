@echo off

REM "C:\Program Files\MongoDB\Server\7.0\bin\mongoimport.exe" 
 
set DB_NAME=D597Task2
set COLLECTION_NAME=groceries
set FILE_PATH=C:\Scenario2\Task2Scenario2Dataset2_Groceries_dataset.json

"C:\Program Files\MongoDB\Server\7.0\bin\mongoimport.exe" --db %DB_NAME% --collection %COLLECTION_NAME% --file %FILE_PATH% --jsonArray

pause
