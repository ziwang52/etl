

test with 5 parameters 

sample:
./etl.sh 40.69.135.45 zwang5 /home/shared/MOCK_MIX_v2.1.csv.bz2 root semester_project
  
remote-server ip, remote-userid, remote file full path, mysql-id, database name

after enter your  mySQL password,

this script will automatic create or replace table SUMMARY and TRANSACTION in your database

after that it will upload these two tables into database;
 
 
command for checking databases:
mysql -u mysql-id -p  --database database_name

#run sample
mysql -uroot -p --database semester_project
 
 Command for checking tables:
 select * from SUMMARY;
 select * from TRANSACTION;