#!/bin/bash
set -e
function getLogs(){
	TAR_FILE_NAME=$1
	## If no containers running return
	CONTAINERS=$(docker ps -a | wc -l)
        if test $CONTAINERS -eq 1
	then
		echo "============= No Docker Containers running =========="
		return
	fi

	printf "=========================================================\n"
	printf "        START CAPTURE ALL DOCKER CONTAINER LOGS \n"
	#printf "=========================================================\n"

        DATE=`date +%Y_%m_%d_%H_%M_%S`
	: ${TAR_FILE_NAME:="$DATE-logs"}
        TAR_FILE="$TAR_FILE_NAME.tar.gz"
	if [ ! -d logs ]; then
		mkdir logs
	fi
	for name in `docker ps --format "{{.Names}}"`
	do
		#printf "\n#### collecting logs for the container $name ####\n"
		docker logs $name >& logs/$name.txt
	done


	## tar the logs
	tar czf logs/$TAR_FILE logs/*.txt

	## cleanup
	rm -rf logs/*.txt

	#printf "=========================================================\n"
	printf "      CAPTURED DOCKER CONTAINER LOGS TO $TAR_FILE \n"
	printf "=========================================================\n"
}
getLogs $1
