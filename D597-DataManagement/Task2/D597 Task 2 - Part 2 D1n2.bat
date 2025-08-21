
@echo off

REM "C:\Program Files\MongoDB\Server\7.0\bin\mongoimport.exe" 
 
set DB_NAME=D597Task2
set COLLECTION_NAME=cosmetics
set FILE_PATH=C:\Scenario2\Task2Scenario2Dataset1_cosmetics.json

"C:\Program Files\MongoDB\Server\7.0\bin\mongoimport.exe" --db %DB_NAME% --collection %COLLECTION_NAME% --file %FILE_PATH% --jsonArray

pause
