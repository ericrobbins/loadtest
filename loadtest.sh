#!/bin/bash

# set up options
outfile=/dev/null
host=www.delta-v.co
# Actual IP to hit, if different than the DNS resolution of the 'host' variable
# used with patched wget in the HOSTOVERRIDE environment variable
ip=54.200.224.155
url=http://${host}/
# I call my modified wget wget2. 
wget=wget2
wgetopts="-q --no-check-certificate --tries=1 --connect-timeout=1 --read-timeout=10"
postdata=""

die() {
	echo "$*"
	rm -f $nowbin ${nowbin}.c > /dev/null 2>&1
	exit 1
}

timenow() {
	if [[ -f $nowbin ]]
	then
		$nowbin
	else
		python -c "import time; print int(time.time() * 1000);"
	fi
}
	
# This is a C program because it executes an order of 
# magnitude faster than a python 1 liner. 
# linux 'date' does microseconds but it's not portable.
nowbin=/tmp/now$$
cat << _EOF_ > ${nowbin}.c
#include <stdio.h>
#include <sys/time.h>

int main(void) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	printf("%llu\n", (tv.tv_sec * 1000ULL) + (tv.tv_usec / 1000ULL));
	return(0);
}
_EOF_

gcc -O2 -o $nowbin ${nowbin}.c > /dev/null 2>&1 || rm -f $nowbin
rm -f ${nowbin}.c

[[ $# -ge 1 && $# -le 2 ]] || die "usage: $0 <numparallelprocs> <duration>"

[[ $ip != "" ]] && export HOSTOVERRIDE=${host}=${ip}

parallel=$1
duration=0
[[ $# -eq 2 ]] && duration=$(( $2 * 1000 ))

[[ $parallel -gt 0 && $parallel -lt 1000 ]] || parallel=1

allstart=$(timenow)

function startproc() {
	i=$1
	begintime=$(timenow)
	(${wget} ${wgetopts} --no-check-certificate -O${outfile} --post-data="$postdata" ${url}; echo $? > /tmp/retcode.$i) &
	child[$i]=$!
	starttime[$i]=$begintime
}

for (( totalrun = 0, i = 1; i <= $parallel; i++, totalrun++ ))
do
	startproc $i
done

#for (( i = 1; i <= $parallel; i++ ))
#do
#	echo child $i starttime ${starttime[$i]}
#done

startmore=1
running=$parallel

echo totalparallel $totalrun, duration $(( $duration / 1000 )) seconds

while [ $running -gt 0 ]
do
	for (( x = 1; x <= $totalrun; x++ ))
	do
		now=$(timenow)
		[[ $duration -gt 0 && $(( $now - $allstart )) -gt $duration ]] && startmore=0
		if [[ ${child[$x]} -ne 0 ]]
		then
			kill -0 ${child[$x]} 2>/dev/null
			if [[ $? -ne 0 ]]
			then	
				retcode[$x]=$(cat /tmp/retcode.$x)
				rm -f /tmp/retcode.$x
				child[$x]=0
				totaltime[$x]=$(( $now - ${starttime[$x]} ))
				[[ ${retcode[$x]} -ne 0 ]] && totaltime[$x]=-1
				if [[ $duration -eq 0 || $startmore -eq 0 ]]
				then
					running=$(( $running - 1 ))
				else
					totalrun=$(( $totalrun + 1 ))
					#echo "child $x died (code ${retcode[$x]}), starting another, totalrun $totalrun"
					startproc $totalrun
				fi
			fi
		fi
	done
done

(for (( i = 1; i <= $totalrun; i++ )); do echo ${totaltime[$i]}; done) | sort -n | awk '
	BEGIN {
		goodcount = 0;
		failures = 0;
	} 
	{
		if ($0 > -1) {
			actual = $1 / 1000.0;
			total += actual;
			goodcount++;
			val[goodcount] = actual;
		}
		else
		{
			failures++;
		}
	} 
	END {
		# awk > 4 needed for 3 arg asort
		#asort(val, val, "number");
		avg = goodcount > 0 ? total / goodcount : 0.0; 
		median = val[int((goodcount + 1) / 2)]; 
		min = val[1];
		max = val[goodcount];
	
		dtot = 0;
		for (i = 1; i <= goodcount; i++)
		{
			dtot += ((val[i] - avg) * (val[i] - avg));
		}
		sdev = goodcount > 0 ? sqrt(dtot / goodcount) : 0.0;
	
		printf("%i tests, %i failures, success rate %.2f%%\n", NR, failures, goodcount / NR * 100.0);
		printf("min time %.2f, max %.2f, average %.2f, median %.2f, std dev %.2f\n", 
			min, max, avg, median, sdev);
	}'

echo ""
rm -f $nowbin > /dev/null 2>&1
exit 0
