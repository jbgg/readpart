#!/bin/sh
## readpart.sh 0.02 jbgg ##





read8(){
	od -t x1 -N 1 $* | awk 'NR==1{print $2}'
}

read16(){
	od -t x2 -N 2 $* | awk 'NR==1{print $2}'
}

read32(){
	od -t x4 -N 4 $* | awk 'NR==1{print $2}'
}



## programexit
programexit()
{
	## print error string
	case $1 in
		0) # no arguments
			echo "usage: `basename $0` device"
			echo "  example: `basename $0` /dev/sdc"
			;;
		1) # device does not exist
			echo "device does not exist";;
		2) # read_partition without arguments
			echo "read_partition without arguments";;
		3) # error reading sector
			echo "error reading sector";;
		*) # general case?
			;;
	esac

	## clean tmp files (if exists)
	if [ ! -z ${cleanfiles} ]; then
		rm -f ${cleanfiles}
	fi

	exit
}



## read_partitions ##
read_partitions()
{
	# arg1: psect
	local psect=$1
	if [ -z ${psect} ]; then
		programexit 2
	fi

	local sectfile=`mktemp`
	cleanfiles="${cleanfiles} ${sectfile}"

	## copy sector
	dd if=${devicename} of=${sectfile} bs=512 count=1 skip=$((0x${psect})) 2>/dev/null
	if [ $? -ne '0' ]; then
		programexit 3
		return
	fi

	local lsig=`read16 -j 0x1fe ${sectfile}`
	if [ ${lsig} != 'aa55' ]; then
		return
	fi

	local loffset=$((0x1be))
	local pnum
	local ltype
	local lstart
	for pnum in 0 1 2 3; do
		ltype=`read8 -j $((loffset+4)) ${sectfile}`
		case ${ltype} in
			'00') # invalid partition
				;;
			'05') # extended partition
				lstart=`read32 -j $((${loffset}+8)) ${sectfile}`
				lstart=`printf "%x" $(( 0x${lstart} + 0x${psect} ))`
				read_partitions ${lstart}
				;;
			*) # other partition
				echo -n ${gpnum}
				echo -n " `read8 -j $((${loffset})) ${sectfile}`"
				echo -n " ${ltype}"
				lstart=`read32 -j $((${loffset}+8)) ${sectfile}`
				lstart=`printf "%x" $(( 0x${lstart} + 0x${psect} ))`
				echo -n " ${lstart}"
				echo " `read32 -j $((${loffset}+0xc)) ${sectfile}`"
				gpnum=$((${gpnum} + 1))
				;;
		esac
		loffset=$((${loffset} + 0x10))
	done



}


if [ -z $1 ]; then
	programexit 0
fi


devicename=$1

# debug
#echo " ** devicename=${devicename}"

# check if file exists
if [ ! -e ${devicename} ]; then
	programexit 1
fi

gpnum=0
partlist=`read_partitions 0`

echo " ** partlist:
${partlist}"



## clean tmp files ##
rm -f ${cleanfiles}

