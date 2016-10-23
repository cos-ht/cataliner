#!/bin/sh

### Test state of a magnolia website and initiate restart if needed.
### Example tuned for deployment under Solaris SMF; requires COSas scripts.
### Runs via crontab
### (C) 2010 by Jim Klimov

### Config
TEST_URL1="/restapi/isRunning"
TEST_URL2="/website/lastUpdates.html"
TEST_HOST=localhost
TEST_PORT=80
TEST_TIMEOUT=20

SMF_SERVICE="magnolia"

LOG_FILE="/var/log/selfcheck-${SMF_SERVICE}.log"
LOCK_FILE="/tmp/selfcheck-${SMF_SERVICE}.lock"

if [ -s "$LOCK_FILE" ]; then
	( echo "`date`: Previous run has not completed yet... Skipping this check."
	svcs -p ${SMF_SERVICE} ) >> ${LOG_FILE} 2>&1
	exit 0
fi

trap "rm -f ${LOCK_FILE}" 0 1 2 3 15
echo $$ > ${LOCK_FILE}
date >> ${LOCK_FILE}

### Work
SMF_STATE="`svcs ${SMF_SERVICE} | grep ${SMF_SERVICE} | awk '{print $1}'`"
if [ "$SMF_STATE" = 'offline*' -o "$SMF_STATE" = 'online*' ]; then
	( echo "`date`: server is still restarting... Skipping this check."
	svcs -p ${SMF_SERVICE} ) >> ${LOG_FILE} 2>&1
	exit 0
fi

NUMPORTS1="`netstat -an | grep -w ${TEST_PORT} |grep -v LISTEN | wc -l | sed 's/ //g'`"
NUMPORTS1e="`netstat -an | grep -w ${TEST_PORT} |grep ESTAB | wc -l | sed 's/ //g'`"

[ -x /opt/COSas/bin/agent-web-portalOra.sh ] && ( 
	/opt/COSas/bin/agent-web-portalOra.sh -t ${TEST_TIMEOUT} -u ${TEST_URL1} ${TEST_HOST} ${TEST_PORT} >/dev/null 2>&1 || (
		NUMPORTS2="`netstat -an | grep -w ${TEST_PORT} |grep -v LISTEN | wc -l | sed 's/ //g'`"
		NUMPORTS2e="`netstat -an | grep -w ${TEST_PORT} |grep ESTAB | wc -l | sed 's/ //g'`"
		echo "`date`: Site seems to have hung. Details: Sockets ($NUMPORTS1 total, $NUMPORTS1e est) -> ($NUMPORTS2 total, $NUMPORTS2e est)"
		echo "---"; cat /tmp/portalOra.test.html; echo "---"

		echo "=== Re-test another URL:"
		/opt/COSas/bin/agent-web-portalOra.sh -t 2 -u ${TEST_URL2} ${TEST_HOST} ${TEST_PORT}
		RET=$?
		echo "---"; cat /tmp/portalOra.test.html; echo "---"

		if [ $RET != 0 ]; then
			echo "=== restarting service"
			svcadm restart ${SMF_SERVICE}
			sleep 10
			svcs -p ${SMF_SERVICE}
		fi
	)
) >> ${LOG_FILE} 2>&1
