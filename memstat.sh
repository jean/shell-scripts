#!/bin/bash 


# Memstat.sh is a shell script that calculates linux memory usage for each program / application. 
# Script outputs shared and private memory for each program running in linux. Since memory calculation is bit complex, 
# this shell script tries best to find more accurate results. Script use 2 files ie /proc//status (to get name of process)
# and /proc//smaps for memory statistic of process. Then script will convert all data into Kb, Mb, Gb. 
# Also make sure you install bc command.
# 
# Source : http://www.linoxide.com/linux-shell-script/linux-memory-usage-program/
# Parent : http://www.linoxide.com/guide/scripts-pdf.html
# 

if [ "$(id -u)" != "0" ]; then
   echo "Reporting memory usage only for the current user. Run as root to get usage for all processes." 1>&2
fi


### Functions
#This function will count memory statistic for passed PID
get_process_mem ()
{
PID=$1
#we need to check if 2 files exist (and are readable)
if test -r /proc/$PID/status && head -n 1 /proc/$PID/status 2>/dev/null 1>/dev/null;
then
	if test -r /proc/$PID/smaps && head -n 1 /proc/$PID/smaps 2>/dev/null 1>/dev/null; 
	then
		#here we count memory usage, Pss, Private and Shared = Pss-Private
		Pss=`cat /proc/$PID/smaps | grep -e "^Pss:" | awk '{print $2}'| paste -sd+ | bc `
		Private=`cat /proc/$PID/smaps | grep -e "^Private" | awk '{print $2}'| paste -sd+ | bc `
		#we need to be sure that we count Pss and Private memory, to avoid errors
		if [ x"$Rss" != "x" -o x"$Private" != "x" ]; 
		then

			let Shared=${Pss}-${Private}
			Name=`cat /proc/$PID/status | grep -e "^Name:" |cut -d':' -f2`
			#we keep all results in bytes
			let Shared=${Shared}*1024
			let Private=${Private}*1024
			let Sum=${Shared}+${Private}

			echo -e "$Private  + $Shared = $Sum \t $Name"
		fi
	fi
fi
}

#this function make conversion from bytes to KB or MB or GB
convert()
{
value=$1
power=0
#if value 0, we make it like 0.00
if [ "$value" = "0" ];
then
	value="0.00"
fi

#We make conversion till value bigger than 1024, and if yes we divide by 1024
while [ $(echo "${value} > 1024"|bc) -eq 1 ]
do
	value=$(echo "scale=2;${value}/1024" |bc)
	let power=$power+1
done

#this part get B,KB,MB or GB according to number of divisions 
case $power in
	0) reg=B;;
	1) reg=KB;;
	2) reg=MB;;
	3) reg=GB;;
esac

echo -n "${value} ${reg} "
}

#to ensure that temp files not exist
[[ -f /tmp/res ]] && rm -f /tmp/res
[[ -f /tmp/res2 ]] && rm -f /tmp/res2
[[ -f /tmp/res3 ]] && rm -f /tmp/res3


# If argument passed, script will show statistics only for that PID, if not,
# we list all processes in /proc/ and get statistics for all of them. 
# All result we store in file /tmp/res
if [ $# -eq 0 ]
then
	pids=`ls /proc | grep -e [0-9] | grep -v [A-Za-z] `
	for i in $pids
	do
	get_process_mem $i >> /tmp/res
	done
else
	get_process_mem $1>> /tmp/res
fi


#This will sort result by memory usage
cat /tmp/res | sort -gr -k 5 > /tmp/res2

#this part will get uniq names from process list, and we will add all lines with same process list 
#we will count number of processes with same name, so if more that 1 process where will be
# process(2) in output
for Name in `cat /tmp/res2 | awk '{print $6}' | sort  | uniq`
do
count=`cat /tmp/res2 | awk -v src=$Name '{if ($6==src) {print $6}}'|wc -l| awk '{print $1}'`
if [ $count = "1" ];
then
	count=""
else 
	count="(${count})"
fi

VmSizeKB=`cat /tmp/res2 | awk -v src=$Name '{if ($6==src) {print $1}}' | paste -sd+ | bc`
VmRssKB=`cat /tmp/res2 | awk -v src=$Name '{if ($6==src) {print $3}}' | paste -sd+ | bc`
total=`cat /tmp/res2 | awk '{print $5}' | paste -sd+ | bc`
Sum=`echo "${VmRssKB}+${VmSizeKB}"|bc`
#all result stored in /tmp/res3 file
echo -e "$VmSizeKB  + $VmRssKB = $Sum \t ${Name}${count}" >>/tmp/res3
done


#this make sort once more.
cat /tmp/res3 | sort -gr -k 5 | uniq > /tmp/res

#now we print result , first header
echo -e "Private \t + \t Shared \t = \t RAM used \t Program"
#after we read line by line of temp file
while read line 
do
	echo $line | while read  a b c d e f
	do
#we print all processes if Ram used if not 0
		if [ $e != "0" ]; then
#here we use function that make conversion 
		echo -en "`convert $a`  \t $b \t `convert $c`  \t $d \t `convert $e`  \t $f"
		echo ""
		fi
	done
done < /tmp/res

#this part print footer, with counted Ram usage
echo "--------------------------------------------------------"
echo -e "\t\t\t\t\t\t `convert $total`"
echo "========================================================"

# we clean temporary file
[[ -f /tmp/res ]] && rm -f /tmp/res
[[ -f /tmp/res2 ]] && rm -f /tmp/res2
[[ -f /tmp/res3 ]] && rm -f /tmp/res3
