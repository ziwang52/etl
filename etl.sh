#!/bin/bash
#Zi Wang
#semester project

# Check parameters are correct
set -o errexit # exit if an error occurs
if (( $# != 5 )) ; then
	echo "Usage: $0 plz enter remote server, remote userID, remote file path,mysql_user_id,mysql_database"; exit 1
fi

# Declare Variables
remote_erver="$1"
remote_userid="$2"
remote_file="$3"
mysql_user_id="$4"
mysql_database="$5"

file_path="$2'@'$1:$3"
src_file="$(basename $file_path)"

#declare -f rm_temps
function rm_temps() {
	read -p "Delete Temporary Files (Y/N) "
	if [[ $REPLY = [Yy] ]]; then
		rm *.tmp
			echo "Temporary files deleted"
		exit 1
	fi
}

#1) Import file from remote_srv folder - mimic for download of file from server
#echo $file_path
scp  $2"@"$1":"$3 .
printf "1) Importing testfile: $src_file -- complete\n"

#2) Extract contents of downloaded file and account for new name
bunzip2 $src_file
main_file=${src_file%.bz2}
printf "2) Unzip file $main_file --complete\n"

#3) Remove the header from the file
tail -n +2 $main_file > "01_rm_header.tmp"
printf "3) Remove header from file -- complete\n"

#4) Convert all text to lower case
tr '[:upper:]' '[:lower:]' < "01_rm_header.tmp" > "02_conv_lower.tmp"
printf "4) Converted all text to lowercase -- complete\n"

# 5) Convert Gender value
 awk 'BEGIN {FS = ","; OFS = ","} {
	if ($5 ~ /1/) {$5 = "f"  }
	if($5 ~ /0/) {$5 = "m" }
	if($5 ~ /^female/) {$5 = "f" }
	if($5 ~ /male/) {$5 = "m" }	
	if($5 ~ /^$/) {$5 = "u" }
	{print}
	}' < "02_conv_lower.tmp" > "03_conv_gender.tmp"
printf "5) Converted gender field -- complete\n"

#6) Filter out all records that do not have a state or contain NA from the State columns
printf "6) Filter out all records do not have a state or contain NA  -- complete\n"
awk 'BEGIN {FS = ","; OFS = ","} {
	if ($12 ~/^$/|| $12 ~/NA/){print}
	}' < "03_conv_gender.tmp" > "exceptions.csv"
#diff 03_conv_gender.tmp exceptions.csv >05_rm_excepetions.tmp 
awk 'BEGIN {FS = ","; OFS = ","} {
	if ($12){print}
	}' < "03_conv_gender.tmp" > "05_rm_excepetions.tmp"
	
#7) Remove the $ sign in the transaction file from the purchase amt field.
printf "7) remove the $ sign in the transaction file  -- complete\n"
 sed 's/\$//g' <"05_rm_excepetions.tmp"> "06_rm_dollar_sign.tmp"
 
#8) Sort transaction file by customerID
printf "8) Sort transaction file by customerID  -- complete\n"
sort -k 1,1 -t','  06_rm_dollar_sign.tmp > "transaction.csv"
transaction_path=$(echo $(pwd)/transaction.csv)

#9)a. calculate total purchase amount
printf "9) generate summary file with total purchase   -- complete\n"
awk 'BEGIN { FS=","; OFS=","}
{a[$1","  $12"," $13"," $3"," $2]+=$6}
END{
	for (i in a){print i, a[i]}	
}' <transaction.csv >07_totalamount.tmp

#9)b. Generate a summary file 
sort  -k 2,2 -k 3,3nr -k 4,4 -k 5,5 -t"," 07_totalamount.tmp > "summary.csv"
summary_path=$(echo $(pwd)/summary.csv)

#10)a. Transaction Report
printf "10) a, create Transaction Report   -- complete\n"
awk 'BEGIN{ 
FS=","; OFS=" "}
{state[toupper($12)]+=1}
END{
for ( i in state){print i , "       " state[i]}
}' <transaction.csv | sort -k 2nr -t " "  > 08_transaction.tmp
awk  'BEGIN{ 
print "Report by: Zi Wang"
print "Transaction Count Report\n\n"
print "State Transaction Count" }{print}' 08_transaction.tmp>transaction.rpt

#10)b. Purchase Report 
printf "10) b, create Purchase Report   -- complete\n"
awk  'BEGIN {FS=",";OFS="\t"} 
       {b[toupper($12)"	       " toupper($5)]+=$6} 
       END {for (i in b) {
           printf "%-3s "      "   %4.2f\n", i,b[i]
           }
       }' <transaction.csv | sort  -f -k 3nr -k 1 -k 2  >09_total_gender_amount.tmp

 awk  'BEGIN{ 
print "Report by: Zi Wang"
print "Purchase Summary Report\n\n"
print "State    Gender    Report" }{print}' 09_total_gender_amount.tmp>purchase.rpt

#11, upload local file in to mariaDB
printf "11) logging into MariaDB $4-- ------ \n"

#create tables in data bases and upload local files
mysql -u $4 -p  --database $5 << EOF

create or replace table TRANSACTION(
customer_id varchar(45),
first_name varchar(6),
last_name varchar(6),
email varchar(30),
gender varchar(2),
purchase_amount  decimal(13,2),
credit_card varchar(20),
transaction_id varchar(45),
transaction_date date,
street varchar(25),
city varchar(15),
state varchar(5),
zip varchar(7),
phone varchar(15)
);

load data local infile '$transaction_path' into table TRANSACTION fields terminated by ',' ;

create or replace table SUMMARY(
customer_id varchar(45),
state varchar(5),
zip varchar(7),
last_name varchar(10),
first_name varchar(10),
total_purchase_amount decimal(13,2)
);

load data local infile '$summary_path' into table SUMMARY fields terminated by ',' ;


EOF
printf "create table of TRANSACTION and SUMMARY------complete\n"
printf "upload local file into table of TRANSACTION and SUMMARY-----complete\n"
#12) Clean up all temp files
rm_temps

