#!/bin/sh
### ===NOTE=== DO NOT MODIFY (DEFAULT) SERVER SETTINGS WITHIN THIS SCRIPT!!!
### These configuration modifications will be overwritten during upgrade!

# chkconfig: 345 98 1
# description: Cataliner-managed appserver
# processname: cataliner
### For RHEL; make sure to start appserver after databases (MySQL/PgSQL/LDAP)

### $Id: cataliner.sh,v 1.116 2014/09/10 17:06:00 jim Exp $

### ===NOTE=== Use 'touch /etc/.cataliner-redirectoutput' to log all
### output of this script's active method invokations (i.e. to debug
### system startup) into uniquely named files for each invokation.
### If this file content is the word "single" then all such logs will be
### concatenated into a single file (one per script base-name, including S98):
###    echo single > /etc/.cataliner-redirectoutput

### !!!!!!!!!!!!!!!!!!     RECOMMENDED INSTALLATION METHOD: !!!!!!!!!!!!!!!!!!!
### 1) Install the most current version of script as /etc/init.d/cataliner.sh:
###    Packaged for (Open)Solaris:
###      wget -O /tmp/COScataliner.pkg.gz $DOWNLOAD_BASEURL/COScataliner.pkg.gz
###      gzcat /tmp/COScataliner.pkg.gz > /tmp/COScataliner.pkg && (pkgrm COScataliner; pkgadd -d /tmp/COScataliner.pkg)
###    Packaged for RHEL/CentOS Linux:
###      rpm -U --force $DOWNLOAD_BASEURL/COScataliner.rpm
###    or manually for any UNIX-like OS:
###          wget -O /etc/init.d/cataliner.sh $DOWNLOAD_BASEURL/cataliner.sh
###      or  curl -o /etc/init.d/cataliner.sh $DOWNLOAD_BASEURL/cataliner.sh
###      and chmod +x /etc/init.d/cataliner.sh
###    Also it is recommended to install/update COSas package with useful
###    administrative scripts to test server availability, do backup, etc.
###    Packaged for (Open)Solaris:
###      wget -O /tmp/COSas.pkg.gz $DOWNLOAD_BASEURL/COSas.pkg.gz
###      gzcat /tmp/COSas.pkg.gz > /tmp/COSas.pkg && (pkgrm COSas; pkgadd -d /tmp/COSas.pkg)
###    Packaged for RHEL/CentOS Linux:
###      rpm -U --force $DOWNLOAD_BASEURL/COSas.rpm
### 2) For each application server software instance on this system,
###    create symlinks to it like this:
###      ln -s cataliner.sh /etc/init.d/magnolia
###      ln -s cataliner.sh /etc/init.d/alfresco
###      ln -s cataliner.sh /etc/init.d/jenkins
###      ln -s cataliner.sh /etc/init.d/livecycle
###      ln -s cataliner.sh /etc/init.d/opensso
###      ln -s cataliner.sh /etc/init.d/glassfish
###    and so on. Don't make copies of the script - it makes updates harder.
### 3) Use one of many configuration methods (config files, SMF attributes)
###    instead of direct script modifications. Wrapper scripts are possible
###    but not recommended now. See code comments below for more details.
###    Config file names are chosen by script's actual invokation name, so
###    if you start /etc/init.d/magnolia, it will use magnolia.conf(.local)
###    file(s) from /etc/default or /etc/sysconfig directory. General config
###    may also be used in cataliner.conf(.local) file, i.e. common JAVA_HOME.
###    NOTE that SMF parameters will override config file parameters, and
###    if you set JAVA_OPTS in configs - it will override any presets from
###    this script. Use JAVA_OPTS_COMMON_ADDITIONAL if you want to JUST
###    ADD an option to this script's default preset values.
###    If appropriate, configure pre-start tests for LDAP/DBMS availability.

### ===NOTE=== DO NOT MODIFY SERVER SETTINGS WITHIN TOMCAT/JBOSS SCRIPTS!!!
### Otherwise we get long strange debugging when configurations don't work ;)

### ===NOTE=== For GlassFish/Sun Appserver, this script only wraps startup
### and shutdown with logfile monitoring. All configs belong in AppServer.
### Customizations for GlassFish should be in /etc/default/glassfish.conf
### or specific /etc/default/glassfish-domain.conf files, and likely include
### LARGE start/stop timeouts; maybe paths and domain/instance/cluster name.

### 4) To register a specific app server for autostart and autostop with
###    OS boot/shutdown do one of these steps (examples for Magnolia wrapper):
### * Solaris 10+ SMF service: Use one of sample XML manifests (Resource link
###    below). Modify manifest XML file as needed, import with commands like:
###      svccfg import /tmp/tomcat-magnolia.xml
###      svcadm refresh magnolia
### * RHEL/CentOS LINUX: Use chkconfig to register a "subsystem", i.e.:
###      chkconfig magnolia reset
### * Generic Linux/Solaris initscript: create /etc/rc?.d symlinks:
###      ln -s ../init.d/magnolia /etc/rc3.d/S98magnolia
###      ln -s ../init.d/magnolia /etc/rc0.d/K01magnolia
###      ln -s ../init.d/magnolia /etc/rc1.d/K01magnolia
###   For RHEL-like Linux also create these links:
###      ln -s ../init.d/magnolia /etc/rc4.d/S98magnolia
###      ln -s ../init.d/magnolia /etc/rc5.d/S98magnolia
###      ln -s ../init.d/magnolia /etc/rc6.d/K01magnolia
###   If the app server depends on other services (LDAP, Database) they
###   should start before (S97 and earlier) and stop after (K02 and later).
### 5) Test that the script works OK and server (re)starts without errors:
###   Any OS:
###      /etc/init.d/magnolia restart
###   Solaris SMF:
###      svcadm restart magnolia
### 6) Reboot server OS to make sure that shutdown and startup work properly.
###    To save script output to log files under Linux and older Solaris (9-):
###      touch /etc/.cataliner-redirectoutput
###    After reboot remove this file and analyze logs /var/log/cataliner-*.log
###    Note that under Solaris 10+ logs are normally saved by SMF:
###    * initscript outputs are saved in /var/svc/log/rc[036].log
###    * SMF service outputs are saved in /var/svc/log/*magnolia*.log
###      or similarly named files (/var/svc/log/application-tomcat:*.log
###	 or /var/svc/log/application-jboss:*.log)

### (C) 2009-2016 Jim Klimov, JSC COS&HT (more below)

### Cataliner.sh - streamlines management (start/top/restart) of
### Tomcat/Catalina-based application servers. Intended for Linux
### (initscript mode) and Solaris servers (initscript, SMF service
### modes) for our application servers (such as Alfresco, Magnolia,
### Jenkins and generic Tomcat, GlassFish, and Adobe Livecycle under
### JBOSS).

### Make a symlink containing the intended service's name (such as
### /etc/init.d/magnolia-init.sh) to control the specified service
### with tuned JVM settings and working paths.

### For custom setups (paths, JVM options) a wrapper init script
### to define required env-vars is encouraged (example Alfresco
### wrapper is provided), or a config file - see loadConfigFiles()
### below for expected filename location and naming conventions.

### This also may be used as a Solaris/illumos SMF service script,
### use svc props named like 'cataliner/CATALINER_VAR_NAME'
### SMF: to work around svc-start timeouts (magnolia/etc. repository
###	checks, or waiting for prerequisite services, can take ages)
###	can use (start|stop)/timeout_seconds = 0 == infinite

### See comments in code for CATALINER_* env-vars used by the script,
### common env-vars for Tomcat Catalina or JBOSS init scripts may also
### be provided and exported by the wrapper, as deemed appropriate.
### NOTE: In particular, an externally defined JAVA_OPTS overrides 
### any JVM tunings in this script done by a lesser variable
### (JAVA_OPTS_COMMON). JAVA_OPTS_START and JAVA_OPTS_STOP and
### CATALINA_OPTS can still be used.

### Magnolia/Solaris init script based on our older Alfresco and Magnolia
### works and the vendors' original scripts (mostly Linux-oriented)
### (C) Apache/Tomcat - initial script for Linux
### (C) Alfresco - initial script for Linux
### (C) Magnolia - initial script for Linux
### (C) 2008-2009 Jim Klimov, JSC COS&HT - heavy updates for Solaris,
###		non-root execution, JAVA_HOME, waiting for JVM to die...
### (C) 2009 Jim Klimov, JSC COS&HT - conversion for Magnolia
### (C) 2009 Jim Klimov, JSC COS&HT - conversion to SMF-capability
### (C) 2010-2012 Jim Klimov, JSC COS&HT - some further patches, RenderX
###		XEP integration, merged tweaks form various field setups,
###		wait for "server started" to appear in log files, use SMF,
###		source config files (settings for actual paths, Java options)
###		check if already running (and/or port busy) and lock files,
###		implement method_status(), allow INIT-script invokation to
###		call svcadm to manipulate corresponding SMF service instance,
###		run spawned programs as an unprivileged user (INIT and SMF),
###		optionally write appserver's stdout/stderr to separate logfile
### (C) 2013 Jim Klimov, JSC COS&HT - added GlassFish/Sun AppServer support
###		Currently limited to a single default domain or node-agent
###		with only placeholders for instance and cluster management.
###		If one installation serves several objects, the one to manage
###		can be specified with CATALINER_GLASSFISH_* variables (see
###		below).
### (C) 2016 Jim Klimov - slight fixup for good old Solaris ksh as /bin/sh
###		Presets for better Jenkins support than as a generic service.

### NOTES to developers: don't forfeit possibility of running in Linux (RHEL)
###
### REMEMBER: as a Solaris initscript, this is run by /bin/sh regardless of
### the shell mentioned in the first line! No fancy bash syntax allowed!
###
### TODO: port status monitoring (processes, ports, page load), perhaps some
###	standalone persistent watchdog thread (like KICKER in COSvboxsvc).
###	For now - a crontab example for COSas agents (Solaris):
###    * * * * * [ -x /opt/COSas/bin/agent-web-portalOra.sh ] && ( /opt/COSas/bin/agent-web-portalOra.sh -t 20 -u /ru/government/Main.html localhost 80 >/dev/null 2>&1 ||  (echo "`date`: Site seems to have hung, restarting service"; svcadm restart magnolia ; sleep 10; svcs -p magnolia) ) >> /var/log/selfcheck-magnolia.log 2>&1
### TODO: SQL server probes (+detect db params?)
###	See also COSjisql package (command-line JDBC client, our test scripts)
### TODO: detect/use bitness (32/64) automatically
### TODO: When running as SMF wrapper, detect JVM also as a child of "this"
###	service's contract. May help in startJVM() when a JVM aborts without
###	process error in external run.sh or catalina.sh, and to correctly
###	stopJVM() "hung" JVMs which no longer use their log file.
### TODO: in stopJVM(), move log file detection to before running the
###	external stop method and test that (if that JVM closes the log
###	file quickly but doesn't die, this should help catch it by PID)
### TODO: fix signal traps so that "tail" and other children are killed
###	even if the script is aborted by Ctrl+C or alike.

######## Initialize a few important global variables (script structure)
_ORIG_CATALINER_DEBUG="$CATALINER_DEBUG"
[ x"$CATALINER_DEBUG" = x -o x"$CATALINER_DEBUG" = x- ] && CATALINER_DEBUG=0
[ "$CATALINER_DEBUG" -ge 0 ] || CATALINER_DEBUG=0

### How do we inspect process lists (in absense of proctree.sh)?
### Default value here, override per-OS somewhere below
PSEF_CMD="ps -ef"

### Hardcore debugging for system startup (NOTE - redirects ALL OUTPUT):
PID_TAIL_REDIRLOG=""
REDIR_LOG=""
case "$1" in
start|stop|restart|lock|unlock)
if [ -f /etc/.cataliner-redirectoutput ]; then
    _REDIR_MODE="`head -1 /etc/.cataliner-redirectoutput`"
    REDIR_LOG="/var/log/cataliner"
    [ x"$_REDIR_MODE" != xsingle ] && \
        REDIR_LOG="$REDIR_LOG-`TZ=UTC date +%Y%m%dZ%H%M%S`"
        ### Add unique timestamp
    REDIR_LOG="$REDIR_LOG-`dirname $0 | sed 's/\//_/g'`_`basename $0`"
    [ x"$_REDIR_MODE" != xsingle ] && \
        REDIR_LOG="$REDIR_LOG"__"`echo "$@" | sed 's/ /_/g'`"
        ### Add command-line parameters
    REDIR_LOG="$REDIR_LOG.log"
    unset _REDIR_MODE

    echo "INFO: file /etc/.cataliner-redirectoutput exists, will redirect ALL OUTPUT to"
    echo "      '$REDIR_LOG'"
    if touch "$REDIR_LOG"; then
        tail -0f "$REDIR_LOG" &
        PID_TAIL_REDIRLOG="$!"
        echo "INFO: Showing a copy here (via tail PID $PID_TAIL_REDIRLOG):"
    fi

    if [ -s "$REDIR_LOG" ]; then
        echo "====================="
        echo ""
        echo ""
        echo ""
        echo ""
        echo ""
    fi >> "$REDIR_LOG"
    exec >> "$REDIR_LOG" 2>&1
else
    _E=0
    case "$_CATALINER_SCRIPT_OS" in
        SunOS) case "`uname -r`" in
                5.1*) ;;
                [12345]*) _E=1;;
            esac
            ;;
        *) _E=1 ;;
    esac
    [ "$_E" = 1 ] && \
        echo "INFO: If you want to log the script's output into a file (i.e. at startup):" && \
        echo "      touch /etc/.cataliner-redirectoutput"
    unset _E
fi
;;
esac

TS_STRING_START="`date` (`TZ=UTC date -u`)"
START_NAME_PARAMS="$0 $@"
echo "INFO: Starting at $TS_STRING_START"
echo "      as '$START_NAME_PARAMS' ..."

### NOTE: See config variables' detailed descriptions below.
### Whitespace-separated lists of configurable variables to use in
### "for I in $LIST; do" clauses for bulk loads and sanity/syntax checks
### in loadConfigSMF(), validateConfig() and such. Note that the routine
### loadConfigFiles() sources whole config files (so they may be scriptlets).
### Values may be as required by non-string type, empty or a minus ("-")
### for enforced-empty (no value would be assigned automatically by this
### script, and value would be emptied before actual use).
### Some values are still required. See also "validateConfigSanity(INT)"
### for defaults which are set into empty variables, even if "minus" exists.

### Sanity: checked to be "true"(yes)|"false"(no)
_CATALINER_CONFIGURABLES_BOOLEAN="\
 CATALINER_NONROOT CATALINER_WAITLOG_FLAG \
 CATALINER_COREDUMPS_DISABLE \
 CATALINER_ALF_OPENOFFICE CATALINER_ALF_VIRTUAL \
 CATALINER_PROBE_DEBUG_ALL CATALINER_PROBE_DEBUG_PRESTART_LDAP \
 CATALINER_PROBE_DEBUG_PRESTART_DBMS CATALINER_PROBE_DEBUG_PRESTART_HTTP \
 CATALINER_PROBE_DEBUG_POSTSTART_AMLOGIN \
 CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG \
 CATALINER_PROBE_PRESTART_LDAP_FLAG CATALINER_PROBE_PRESTART_LDAP_FALLBACK_TCP \
 CATALINER_PROBE_PRESTART_DBMS_FLAG CATALINER_PROBE_PRESTART_DBMS_FALLBACK_TCP \
 CATALINER_PROBE_PRESTART_HTTP_FLAG CATALINER_PROBE_PRESTART_HTTP_FALLBACK_TCP \
 CATALINER_APPSERVER_LOGFILE_RENAME \
 CATALINER_SMF_CONFIGFILE_EXCLUSIVE"

### Sanity: if set, should be a whole number ($VAL+0==$VAL without errors).
_CATALINER_CONFIGURABLES_INTEGER="\
 CATALINER_DEBUG \
 CATALINER_FILEDESC_LIMIT \
 CATALINER_WAITLOG_TIMEOUT CATALINER_WAITLOG_TIMEOUT_OPENLOG \
 CATALINER_WAITLOG_INCLUDELAST \
 CATALINER_TIMEOUT_STOP_METHOD CATALINER_TIMEOUT_STOP_TERM \
 CATALINER_TIMEOUT_STOP_KILL CATALINER_TIMEOUT_STOP_ABORT \
 CATALINER_HARDLOCK_SMF_SLEEP \
 CATALINER_PROBE_PRESTART_LDAP_TIMEOUT \
 CATALINER_PROBE_PRESTART_DBMS_TIMEOUT \
 CATALINER_PROBE_PRESTART_HTTP_TIMEOUT \
 CATALINER_PROBE_PRESTOP_DELAY CATALINER_PROBE_POSTSTOP_DELAY \
 CATALINER_PROBE_PRESTART_DELAY CATALINER_PROBE_POSTSTART_DELAY \
 CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT "

### Sanity: String should point to an existing non-empty readable file
_CATALINER_CONFIGURABLES_PATH_FILE="\
 CATALINER_SMF_CONFIGFILE_PATH \
 CATALINER_PROBE_PRESTART_LDAP_PASSFILE"

### Sanity: String should point to an existing non-empty executable file
_CATALINER_CONFIGURABLES_PATH_PROGRAM="\
 CATALINER_APPSERVER_TOMCATCTL \
 CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM"

### Sanity: String should point to an existing readable+executable directory
_CATALINER_CONFIGURABLES_PATH_DIR="\
 JAVA_HOME CATALINER_WORKDIR \
 CATALINER_APPSERVER_DIR CATALINER_APPSERVER_BINDIR \
 CATALINER_APPSERVER_VARDIR \
 CATALINER_ALF_HOME"

### Sanity: Any string, no requirements. May include non-existant files.
_CATALINER_CONFIGURABLES_STRING="\
 $_CATALINER_CONFIGURABLES_PATH_FILE $_CATALINER_CONFIGURABLES_PATH_DIR \
 CATALINER_APPSERVER_MONFILE CATALINER_APPSERVER_LOGFILE \
 CATALINER_APPSERVER_NOHUPFILE CATALINER_APPSERVER_NOHUPFILE_WRITE \
 CATALINER_SCRIPT_APP CATALINER_SCRIPT_JVMBITS \
 CATALINA_OPTS JAVA_OPTS JAVA_OPTS_COMMON_ADDITIONAL \
 JAVA_OPTS_START JAVA_OPTS_STOP JAVA_OPTS_COMMON \
 CATALINER_REGEX_STARTING CATALINER_REGEX_STOPPING CATALINER_REGEX_STOPPED \
 CATALINER_REGEX_STARTED CATALINER_REGEX_FAILURES CATALINER_REGEX_STACKTRACE \
 CATALINER_JBOSS_CONFIG CATALINER_JBOSS_BINDIP \
 CATALINER_GLASSFISH_ADMINOPTS \
 CATALINER_GLASSFISH_DOMAIN CATALINER_GLASSFISH_NODEAGENT \
 CATALINER_GLASSFISH_CLUSTER CATALINER_GLASSFISH_INSTANCE \
 CATALINER_NONROOT_USERNAME \
 CATALINER_PROBE_PRESTART_LDAP_METHOD \
 CATALINER_PROBE_PRESTART_LDAP_HOST CATALINER_PROBE_PRESTART_LDAP_PORT \
 CATALINER_PROBE_PRESTART_LDAP_USER CATALINER_PROBE_PRESTART_LDAP_PASS \
 CATALINER_PROBE_PRESTART_LDAP_BASEDN CATALINER_PROBE_PRESTART_LDAP_FILTER \
 CATALINER_PROBE_PRESTART_DBMS_METHOD CATALINER_PROBE_PRESTART_DBMS_ENGINE \
 CATALINER_PROBE_PRESTART_DBMS_HOST CATALINER_PROBE_PRESTART_DBMS_PORT \
 CATALINER_PROBE_PRESTART_DBMS_USER CATALINER_PROBE_PRESTART_DBMS_PASS \
 CATALINER_PROBE_PRESTART_DBMS_DB CATALINER_PROBE_PRESTART_DBMS_SQL \
 CATALINER_PROBE_PRESTART_HTTP_METHOD CATALINER_PROBE_PRESTART_HTTP_HOST \
 CATALINER_PROBE_PRESTART_HTTP_PORT CATALINER_PROBE_PRESTART_HTTP_URL \
 CATALINER_PROBE_PRESTART_HTTP_PROGRAM CATALINER_PROBE_PRESTART_HTTP_OPTIONS \
 CATALINER_USE_SMF_FMRI CATALINER_DEBUG_RUNAS \
 CATALINER_LANG CATALINER_LC_ALL \
 LOCK LANG LC_ALL"

### List 'em all!
_CATALINER_CONFIGURABLES="\
 $_CATALINER_CONFIGURABLES_BOOLEAN \
 $_CATALINER_CONFIGURABLES_STRING \
 $_CATALINER_CONFIGURABLES_INTEGER"

########### Variable Descriptions
### * Managed application type (one cataliner code can manage many app configs)
###  CATALINER_SCRIPT_APP		want to set app type explicitly?
###			See example values below, otherwise app type is
###			derived from script name or SMF_FMRI service name.
###  CATALINER_USE_SMF_FMRI		if the app is configured to use SMF,
###			we should catch and re-route direct INIT-script calls.
###			A forced-empty value ("-") enforces old INIT behavior.
### * SMF mode config file modifiers:
###  CATALINER_SMF_CONFIGFILE_PATH	dir+filename for config file
###			when this script runs in SMF-method mode
###			(to load vars from a file, not [only] svc props)
###  CATALINER_SMF_CONFIGFILE_EXCLUSIVE	false|true - try this file only?
###			NOTE: if "true" and the file doesn't exist, other
###			possible config files will NOT be used either.
###			If "true", warning is logged anyway that only
###			one config file is checked, whether it exists or not.
### * System resource limits
###  CATALINER_COREDUMPS_DISABLE	(true|false) Use "ulimit -c 0" to
###			disable saving of JVM core dump files (default: true)
###  CATALINER_FILEDESC_LIMIT	(int) Use "ulimit -n" to increase the number
###			of file descriptors (and network sockets)? "unlimited"
###			doesn't work well (java and some other processes go
###			crazy), better use large value like "65536" (default);
###			64-bit processes seem okay.
###			-1 = "unlimited"
###			0  = don't tweak
###			>0 = try to set FD limit
### * Non-root servers (i.e. alfresco) shouldn't run as 'root'
###   to avoid file/directory ownership conflicts afterwards
###  CATALINER_NONROOT	"true" if service should abort if run as root
###			i.e. not to clobber file/dir access rights
###  CATALINER_NONROOT_USERNAME	to "su", auto-find home, etc.
###			It is currently assumed that script's current
###			executing user has access to read log files, etc.
### * App server paths
###  CATALINER_APPSERVER_DIR	generic root of tomcat/jboss container
###  CATALINER_APPSERVER_BINDIR	dir of actual webcontainer's scripts
###  CATALINER_APPSERVER_VARDIR	dir of data files (used for GlassFish now as
###			the container for domains/, nodeagents/, etc. subdirs)
###  CATALINER_APPSERVER_MONFILE	monitor this file. If it is 
###			read by a Java process, consider the server
###			JVM is alive. Typically the log file...
###  CATALINER_APPSERVER_NOHUPFILE	file where to redirect app server's
###			stdout and stderr (currently used for JBOSS nohup)
###  CATALINER_APPSERVER_NOHUPFILE_WRITE (false|append|overwrite)
###			should we write to nohupfile? how?
###  CATALINER_APPSERVER_LOGFILE_RENAME	(false[tomcat default]|true[jboss def])
###			If true, rename the log file after shutdown to pattern
###			$LOGFILE.YYYY-MM-DD_shutdown-NUM.log (or before start,
###			if it exists). Needed: JBOSS overwrites logs on start.
###  CATALINER_APPSERVER_TOMCATCTL	Some tomcat versions lack the scripts
###			startup.sh and stop.sh and use a single init-like
###			script to launch the JVM.
### * Analysis of server log files:
###  CATALINER_APPSERVER_LOGFILE	suggest that invoker (person)
###			monitors this log file with "tail -f"
###			Script also tries to monitor the log file for
###			"Started in XXX ms" messages
###  CATALINER_REGEX_STARTED		see just above - start complete.
###  CATALINER_REGEX_STARTING	\	Regexps to analyze beginning and
###  CATALINER_REGEX_STOPPING	|->	finishing of appserver startup
###  CATALINER_REGEX_STOPPED	/	or shutdown, if logged...
###  CATALINER_REGEX_FAILURES		Count startup failure
###					description lines.
###  CATALINER_REGEX_STACKTRACE		Count startup failure lines
###					which are stack traces.
###  CATALINER_WAITLOG_FLAG		if "true", do track
###			logfile with the regex to wait for server
###			startup before exiting the script
###  CATALINER_WAITLOG_TIMEOUT		if set, limit waitLog and waitLogOpen
###  CATALINER_WAITLOG_TIMEOUT_OPENLOG	if set, limit waitLogOpen
###  CATALINER_WAITLOG_INCLUDELAST	How many existing lines of log
###			file are included ( >= 0 )? empty value
###			means "tail" default = 10.
###			Non-zero values are useful if the startup
###			script/method of the appserver already waits
###			for such line and exits only afterwards
### * Ever-growing stop timeouts for a more pressing "stopJVM"
###  CATALINER_TIMEOUT_STOP_METHOD	These 4 timeouts are used
###  CATALINER_TIMEOUT_STOP_TERM	in this order while stopping
###  CATALINER_TIMEOUT_STOP_KILL	an app server (method stopJVM)
###  CATALINER_TIMEOUT_STOP_ABORT	to TERM or KILL it or give up.
###			KILL and ABORT may equal 0 to disable them.
###  CATALINER_WORKDIR	change to this dir before start. Clobber with
###			runtime logs of nohup, etc.
### * Alfresco-specific settings
###  CATALINER_ALF_HOME	(/opt/alfresco) base path
###  CATALINER_ALF_OPENOFFICE  (yes|no) Start OpenOffice?
###			May also require a valid DISPLAY (i.e. to VNC)
###  CATALINER_ALF_VIRTUAL	(yes|no) Start Virtual Server (WCM)?
### * JBOSS-specific settings
###  CATALINER_JBOSS_CONFIG	config dir name ("all", etc.)
###			Note that JBOSS run.sh may seek and include config
###			files like server/$CATALINER_JBOSS_CONFIG/run.conf
###			and/or generic bin/run.conf
###  CATALINER_JBOSS_BINDIP	IP address for server binding
###			(default = "0.0.0.0" for "all configured IPs")
### * GlassFish/Sun Appserver specific settings
###  CATALINER_GLASSFISH_ADMINOPTS	possible options for asadmin,
###			such as "--user admin --passwordfile /.as8pass"
###  CATALINER_GLASSFISH_DOMAIN  	name of "domain" to manage
###  CATALINER_GLASSFISH_NODEAGENT	name of "node-agent" to manage
###  CATALINER_GLASSFISH_CLUSTER	name of "cluster" to manage
###  CATALINER_GLASSFISH_INSTANCE	name of "instance" to manage
### * Probes: Some deployments may need to probe dependency services
###   or output of started web-applications.
###  CATALINER_PROBE_POSTSTART_DELAY	General delay (if >0) after startup
###			before running probes or exiting: let server initialize
###  CATALINER_PROBE_PRESTOP_DELAY	Likewise before JVM shutdown
###  CATALINER_PROBE_POSTSTOP_DELAY	Likewise after JVM shutdown
###  CATALINER_PROBE_PRESTART_DELAY	Likewise before dependency probes
###  CATALINER_PROBE_DEBUG_ALL		(true|false) Display detailed probe
###  CATALINER_PROBE_DEBUG_PRESTART_LDAP	information instead of just
###  CATALINER_PROBE_DEBUG_PRESTART_DBMS	dots for attempts?
###  CATALINER_PROBE_DEBUG_PRESTART_HTTP	Default: false for all
###  CATALINER_PROBE_DEBUG_POSTSTART_AMLOGIN
### ** LDAP server availability probe:
###  CATALINER_PROBE_PRESTART_LDAP_FLAG		(false|true)
###  CATALINER_PROBE_PRESTART_LDAP_FALLBACK_TCP	(false|true)
###			If a non-tcpip_probe method fails, try the simple way?
###  CATALINER_PROBE_PRESTART_LDAP_TIMEOUT	(0 or more)
###			Wait for a specified number of cycles
###			(probe + sleep 1) or "0" = indefinitely.
###  CATALINER_PROBE_PRESTART_LDAP_METHOD
###	Method can be a string that is executed in-line, such as
###	the name of one of pre-defined routines in this file:
###	'probeldap_ldapsearch' and 'probeldap_tcpip_probe'.
###	Can be an inline shell script. Should return "0" status
###	if ok, non-"0" if probe failed and cycle should go on.
###	Viable (exagerrated) inline script example would look like:
###	_METHOD="( ldapsearch -h '$LDAP_HOST' -p '$LDAP_PORT' -b 'cn=schema' '(objectclass=*)' dn; exit $? )"
###	NOTE: more testing is needed to stick this line into
###		SMF along with evaluatable shell variables
###  CATALINER_PROBE_PRESTART_LDAP_HOST		IP / hostname
###  CATALINER_PROBE_PRESTART_LDAP_PORT		TCP port number or name
###  CATALINER_PROBE_PRESTART_LDAP_USER		login to ldap
###  CATALINER_PROBE_PRESTART_LDAP_PASS		login to ldap or
###  CATALINER_PROBE_PRESTART_LDAP_PASSFILE	also login to ldap
###  CATALINER_PROBE_PRESTART_LDAP_BASEDN	Base DN (cn=schema)
###  CATALINER_PROBE_PRESTART_LDAP_FILTER	LDAP filter (objectclass=*)
### ** DBMS (SQL Database) server availability probe:
###  CATALINER_PROBE_PRESTART_DBMS_FLAG		(false|true)
###  CATALINER_PROBE_PRESTART_DBMS_FALLBACK_TCP	(false|true)
###			If a non-tcpip_probe method fails, try the simple way?
###  CATALINER_PROBE_PRESTART_DBMS_TIMEOUT	(0 or more)
###			Wait for a specified number of cycles
###			(probe + sleep 1) or "0" = indefinitely.
###  CATALINER_PROBE_PRESTART_DBMS_ENGINE	(mysql|pgsql|oracle)
###  CATALINER_PROBE_PRESTART_DBMS_METHOD
###	Method can be a string that is executed in-line, such as
###	the name of one of pre-defined routines in this file:
###	'probedbms_jisql' (not implemented) and 'probedbms_tcpip_probe',
###	or (not implemented) routines to call on original client programs:
###	'probedbms_mysql', 'probedbms_pgsql', 'probedbms_oracle' etc.
###	(may require correct PATH settings, etc.)
###	Can be an inline shell script. Should return "0" status
###	if ok, non-"0" if probe failed and cycle should go on.
###	Viable (exagerrated) inline script example would look like:
###	_METHOD="( ldapsearch -h '$LDAP_HOST' -p '$LDAP_PORT' -b 'cn=schema' '(objectclass=*)' dn; exit $? )"
###	NOTE: more testing is needed to stick this line into
###		SMF along with evaluatable shell variables
###  CATALINER_PROBE_PRESTART_DBMS_HOST		IP / hostname
###  CATALINER_PROBE_PRESTART_DBMS_PORT		TCP port number or name
###  CATALINER_PROBE_PRESTART_DBMS_USER		login to dbms
###  CATALINER_PROBE_PRESTART_DBMS_PASS		login to dbms
###  CATALINER_PROBE_PRESTART_DBMS_DB		database name in dbms
###  CATALINER_PROBE_PRESTART_DBMS_SQL		SQL request for test (jisql)
### ** an HTTP server or service availability tested by a program with params:
###  CATALINER_PROBE_PRESTART_HTTP_FLAG		(false|true)
###  CATALINER_PROBE_PRESTART_HTTP_FALLBACK_TCP	(false|true)
###			If a non-tcpip_probe method fails, try the simple way?
###  CATALINER_PROBE_PRESTART_HTTP_TIMEOUT	(0 or more)
###			Wait for a specified number of cycles
###			(probe + sleep 1) or "0" = indefinitely.
###  CATALINER_PROBE_PRESTART_HTTP_METHOD
###	Method can be a string that is executed in-line, such as
###	the name of one of pre-defined routines in this file:
###	'probehttp_program' or 'probehttp_tcpip_probe' (needs HOST and PORT).
###	Can be an inline shell script. Should return "0" status
###	if ok, non-"0" if probe failed and cycle should go on.
###  CATALINER_PROBE_PRESTART_HTTP_HOST		IP / hostname (for TCP probe)
###  CATALINER_PROBE_PRESTART_HTTP_PORT		TCP port number or name
###  CATALINER_PROBE_PRESTART_HTTP_URL		GET the URL (/)
###  CATALINER_PROBE_PRESTART_HTTP_PROGRAM	path to script (for program 
###			probe), if not default "/opt/COSas/bin/agent-web.sh"
###  CATALINER_PROBE_PRESTART_HTTP_OPTIONS	options for the script
###			Note that option tokens with spaces ARE a problem,
###			so use scripts/programs with config files instead
### ** Access Manager / OpenSSO login ability. Configuration is
###    stored in config file for COSas:check-amserver-login.sh
###  CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG	(false|true)
###  CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM	path to script
###	if not default "/opt/COSas/bin/check-amserver-login.sh"
###  CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT	optional login timeout
### * Components of generic JAVA_OPTS
###  JAVA_OPTS_START	(Optional) Java runtime options used when the
###			 "start" or "run" command is executed.
###  JAVA_OPTS_STOP	(Optional) Java runtime options used when the
###			 "stop" command is executed.
###  JAVA_OPTS_COMMON	(Optional) Java runtime options used when the
###			 "start", "stop", or "run" command is executed.
###  JAVA_OPTS_COMMON_ADDITIONAL (Optional) Java runtime options used when
###			 the "start", "stop", or "run" command is executed,
###			 not set in script (only in custom config methods).
### * Exported Apache/Catalina options like:
###  CATALINA_OPTS	(Optional) Java runtime options used when the
###			 "start" or "run" command is executed.
###			 NOTE: This is only used by Apache Catalina
###			 but not by JBOSS app server, for example.
###  JAVA_OPTS		(Optional) Java runtime options used when the
###			 "start", "stop", or "run" command is executed.
###			 Merged from 2 of 3 variables above, or directly
###			 inherited from caller (like a wrapper script)
###			- then it overrides our JAVA_OPTS_* env-vars
#############################################################################
### * Internally used variables for script itself, which may be set outside:
###  CATALINER_DEBUG	>= 0 do display more or less debugging output
###  CATALINER_DEBUG_RUNAS	if not empty, print debug on calculation
###			and usage of run_as() routine
###  LOCK		Base path name for lock file (should be unique per
###			each managed application regardless of script name)
###			Also used for hard-locking
###  CATALINER_LANG	If defined, overrides the LANG envvar for appserver
###  CATALINER_LC_ALL	If defined, overrides the LC_ALL envvar for appserver
#############################################################################

#############################################################################
### Small helper routines
echodot() {
	### Echoes a dot character without carriage return/linefeed
	### if possible...
	[ $# != 0 ] && DOT="$1" || DOT="."

	case "$_CATALINER_SCRIPT_OS" in
		SunOS) /bin/echo "$DOT\c" ;;
		Linux) echo -e "$DOT\c" ;;
		*) echo "$DOT" ;;
	esac
}

echo_noret() {
	### Echoes "$@" without carriage return/linefeed if possible...
	case "$_CATALINER_SCRIPT_OS" in
		SunOS) /bin/echo "$@\c" ;;
		Linux) echo -e "$@\c" ;;
		*) echo "$@" ;;
	esac
}

cleanExit() {
	TS_STRING_FINISHED="`date` (`TZ=UTC date -u`)"
	echo "INFO: Finished at $TS_STRING_FINISHED"
	echo "      (started at $TS_STRING_START"
	echo "      as '$START_NAME_PARAMS') with result code $1"

	[ x"$REDIR_LOG" != x -a -s "$REDIR_LOG" ] && \
		echo "      Script output was logged into '$REDIR_LOG'"

	for _PID in "$PID_TAIL_REDIRLOG" "$WAITLOG_PID" "$SMF_LOG_PID"; do
		[ x"$_PID" != x -a -d "/proc/$_PID" ] && kill -15 $_PID
	done
	unset _PID

	clearLock

	trap '' 0 1 2 3 15
	exit $1
}

cleanExitStop() {
	echo "`date`: Aborting the script due to errors above and stopping JVM..." >&2
	stopJVM
	cleanExit $1
}

### Some addition routines: echo mathematical result of "$1 $2 $3"
### Not all platforms might support all methods...
math_bc() {
	echo "$1 $2 $3" | bc
}

math_expr() {
	expr "$1" "$2" "$3"
}

math_bash() {
	echo "$(($1 $2 $3))"
}

MATH_MODE="expr"
detectMath() {
    MATH_MODE=""
    ### Detect if BC or EXPR binaries exist
    [ -x /bin/bc -o -x /usr/bin/bc -o -x /usr/local/bin/bc ] && MATH_MODE=bc
    [ -x /bin/expr -o -x /usr/bin/expr -o -x /usr/local/bin/expr ] && MATH_MODE=expr

    ### Detect if we are executed by BASH
    _TEST_SHELL="`head -1 "$0" | sed 's/^\#\!//' | awk '{print $1}'`" || _TEST_SHELL=""
    [ x"$_TEST_SHELL" = x ] && _TEST_SHELL="/bin/sh"
    echo "" | "$_TEST_SHELL" --version | grep "GNU bash" >/dev/null
    [ $? = 0 ] && MATH_MODE=bash
    unset _TEST_SHELL

    ### Detect if our shell by chance has builtins, or PATH has expr or bc...
    if [ x"$MATH_MODE" = x ]; then
        for M in bc expr bash; do
            OUT="`math_$M 1 2 2>/dev/null`" || OUT=""
            [ x"$OUT" = x3 ] && MATH_MODE=$M
        done
    fi

    if [ x"$MATH_MODE" = x ]; then
        echo "FATAL ERROR: No way found to evaluate mathematical expressions!" >&2
        cleanExit $SMF_EXIT_ERR_FATAL
    else
        [ "$CATALINER_DEBUG" -ge 1 ] && echo "===== INFO: Detected math mode: $MATH_MODE"
    fi
}

math() {
    math_${MATH_MODE} "$1" "$2" "$3"
}

add() {
    math "$1" "+" "$2"
}

incr() {
    ### Increments variable named in $1 by number $2
    VAR=$1
    eval VAL="\$$VAR"
    INCR=$2
    [ x"$INCR" = x ] && INCR=1

    eval $VAR=\"`add $VAL $INCR`\"
}

### MATH TESTS
#A=12
#echo "$A"
#incr A
#echo "$A"
#incr A 5
#echo "$A"
#exit 0

#############################################################################
### Reverse lines of a file "$1" or stdin
REVLINE_MODE=""
revlines() {
    [ x"$REVLINE_MODE" = x ] && case "`which tac 2>&1`" in
        /*) REVLINE_MODE="tac" ;;
    esac
    [ x"$REVLINE_MODE" = x ] && case "`which gtac 2>&1`" in
        /*) REVLINE_MODE="gtac" ;;
    esac
    [ x"$REVLINE_MODE" = x ] && case "`which perl 2>&1`" in
        /*) REVLINE_MODE="perl -e 'print reverse <>' " ;;
    esac
    [ x"$REVLINE_MODE" = x ] && case "`which nawk 2>&1`" in
        /*) REVLINE_MODE="nawk '{a[i++]="'$'"0} END {for (j=i-1; j>=0;) print a[j--] }'" ;;
    esac
    [ x"$REVLINE_MODE" = x ] && case "`which gawk 2>&1`" in
        /*) REVLINE_MODE="gawk '{a[i++]="'$'"0} END {for (j=i-1; j>=0;) print a[j--] }'" ;;
    esac
    [ x"$REVLINE_MODE" = x ] && case "`which awk 2>&1`" in
        /*) REVLINE_MODE="awk '{a[i++]="'$'"0} END {for (j=i-1; j>=0;) print a[j--] }'" ;;
    esac
    ### Also possible are "tail -r" - not everywhere, and VERY SLOW sed scripts
    ###   sed '1!G;h;$!d'  or   sed -n '1!G;h;$p'  and head|tail loop tricks
    ### In Sol testing - perl 0.2s, nawk 0.5s, awk 14s, sed 18 min
    ### In Linux testing - awk/gawk 6-8s, perl ~2.5-3s, tac 1.5-2.5s, sed forever

    RES=127
    if [ x"$REVLINE_MODE" = x ]; then
        echo "ERROR: revlines() could not detect a working quick method to reverse input lines" >&2
        RES=1
    else
        if [ $# -gt 0 ]; then
            cat "$@" | eval $REVLINE_MODE
            RES=$?
        else
            eval $REVLINE_MODE
            RES=$?
        fi
    fi
    return $RES
}

#############################################################################
### Routines which work with configuration variables

saveOrigVars () {
### Save some potentialy set external variables
### Maybe useful to revert to original values, i.e during restart()

	for VAR in $_CATALINER_CONFIGURABLES; do
		eval VAL="\$$VAR"
		eval ORIG_$VAR=\"$VAL\"
	done

	if [ "$CATALINER_DEBUG" -gt 2 ]; then
		echo "Saved orig vars:"
		set | egrep '^ORIG_'
		echo ---
	fi
}

NUM_CFG_FILES=0
loadConfigFiles() {
### Set overrides (over hardcoded defaults) from generic config files.
### Then set overrides from per-$0 or per-instance config files...
###
### Notation: *.conf files may be delivered with package updates, don't modify
### *.conf.local files may be defined locally on each final system
### Paths: /etc/default = Solaris, /etc/sysconfig = RHEL
###
### Ordering (each file is applied if exists):
###	cataliner.conf*		= Common configs for whole framework
###	"`basename $0 .sh`".conf* = Config as defined by script name
###		(may be "cataliner", may be symlink name like "S99alfresco")
###	Truncated basename
###	"$CATALINER_SCRIPT_APP".conf* = Config as defined by application name
###	Truncated CATALINER_SCRIPT_APP
###   "Truncated" names are those without "-?(tomcat|jboss|generic|init)-?"
###   i.e. to use "alfresco.conf" for "alfresco-tomcat.sh"
###
###
###   Notes on config files vs. SMF setup:
###
### It's not typical to use config files for SMF services,
### but their use simplifies conversion and maintenance ;)
###
### If this is an SMF invokation (SMF_FMRI is defined) then any defined 
### SMF properties will override values from env-vars and config files; but
### other values (undef in SMF) will be inherited from env/config/hardcoding.
###
### There is an SMF option to specify a certain config file name for inclusion
### for an instance, to override or even replace other config files.

	if [ x"$SMF_FMRI" != x ]; then
		GETPROPARG_QUIET=true
		GETPROPARG_INHERIT=false
		export GETPROPARG_INHERIT GETPROPARG_QUIET
		CATALINER_SMF_CONFIGFILE_PATH="`getproparg cataliner/CATALINER_SMF_CONFIGFILE_PATH`" || CATALINER_SMF_CONFIGFILE_PATH=""
		CATALINER_SMF_CONFIGFILE_EXCLUSIVE="`getproparg cataliner/CATALINER_SMF_CONFIGFILE_EXCLUSIVE`" || CATALINER_SMF_CONFIGFILE_EXCLUSIVE="false"
	fi

	CFG_FILES=""
	if [ x"$CATALINER_SMF_CONFIGFILE_EXCLUSIVE" = x"true" ]; then
		### Value may be empty or invalid file name, will be checked below
		CFG_FILES="$CATALINER_SMF_CONFIGFILE_PATH"

		if [ x"$CATALINER_SMF_CONFIGFILE_PATH" != x -a \
		     x"$CATALINER_SMF_CONFIGFILE_PATH" != x- -a \
		     -s "$CATALINER_SMF_CONFIGFILE_PATH" -a \
		     -r "$CATALINER_SMF_CONFIGFILE_PATH" \
		]; then
			echo "INFO: CATALINER_SMF_CONFIGFILE_EXCLUSIVE=true is in SMF service properties, so"
			echo "    I will only try CATALINER_SMF_CONFIGFILE_PATH='$CATALINER_SMF_CONFIGFILE_PATH'!"
		else
			echo "WARN: CATALINER_SMF_CONFIGFILE_EXCLUSIVE=true is in SMF service properties, but"
			echo "    file CATALINER_SMF_CONFIGFILE_PATH='$CATALINER_SMF_CONFIGFILE_PATH'"
			echo "    is not available or readable. I WILL NOT try other cataliner config files!"
		fi
	else
		### chop off '.sh' if available, to keep it simple
		BASENAME="`basename "$0" .sh | sed 's/^[SK][01234567890][01234567890]//'`"
		BASENAME_TRUNC="`echo "$BASENAME" | sed 's/-*tomcat-*//' | sed 's/-*jboss-*//' | sed 's/-*generic-*//' | sed 's/-*init-*//'`" || BASENAME_TRUNC=""
		[ x"$BASENAME" = x"$BASENAME_TRUNC" ] && BASENAME_TRUNC=""

		CATAPP_TRUNC="`echo "$CATALINER_SCRIPT_APP" | sed 's/-*tomcat-*//' | sed 's/-*jboss-*//' | sed 's/-*generic-*//' | sed 's/-*init-*//'`" || CATAPP_TRUNC=""
		[   x"$CATAPP_TRUNC" = x"$CATALINER_SCRIPT_APP" \
		 -o x"$CATAPP_TRUNC" = x"$BASENAME_TRUNC" \
		 -o x"$CATAPP_TRUNC" = x"$BASENAME" ] && CATAPP_TRUNC=""

		CFG_DIRS="/etc/default /etc/sysconfig"

		CFG_SHORTNAMES="cataliner"
		[ "$BASENAME" != "cataliner" ] && CFG_SHORTNAMES="$CFG_SHORTNAMES $BASENAME $BASENAME_TRUNC"
		[    "$CATALINER_SCRIPT_APP" != "cataliner" \
		  -a "$CATALINER_SCRIPT_APP" != "$BASENAME" \
		  -a "$CATALINER_SCRIPT_APP" != "$BASENAME_TRUNC" \
		] && CFG_SHORTNAMES="$CFG_SHORTNAMES $CATALINER_SCRIPT_APP $CATAPP_TRUNC"

		for F in $CFG_SHORTNAMES; do
		for D in $CFG_DIRS; do
		for E in .conf .conf.local; do
			CFG_FILES="$CFG_FILES $D/$F$E"
		done; done; done

		CFG_FILES="$CFG_FILES $CATALINER_SMF_CONFIGFILE_PATH"
	fi

	for CFG in $CFG_FILES; do
		### Override hardcoding with config files
		if [ -s "$CFG" -a -r "$CFG" ]; then
		    echo "===== Sourcing config file: '$CFG'..."
		    . "$CFG" && incr NUM_CFG_FILES
		fi
	done
}

NUM_CFG_SMF=0
loadConfigSMF() {
	### Set overrides from SMF service properties if applicable...
	if [ x"$SMF_FMRI" != x ]; then
	    if [ x"$_CATALINER_SCRIPT_FRAMEWORK" = x"smf" -o \
		 x"$_CATALINER_SCRIPT_FRAMEWORK" = x"initRunSMF" \
	    ]; then

		_CATALINER_CONFIGURABLES_REGEX=`echo "$_CATALINER_CONFIGURABLES" | sed 's/  / /g' | sed 's/^ //' | sed 's/ $//' | sed 's/ /|/g'`
		_TMP=""
		while [ "$_TMP" != "$_CATALINER_CONFIGURABLES_REGEX" ]; do
			_TMP="$_CATALINER_CONFIGURABLES_REGEX"
			_CATALINER_CONFIGURABLES_REGEX=`echo "$_CATALINER_CONFIGURABLES_REGEX" | sed 's/||/|/g'`
		done		

		PROPS_SVC=`svccfg -s "$CATALINER_SMF_SERVICE" listprop | egrep '^cataliner/' | sed 's/^cataliner\///' | while read VAR TYPE VAL; do echo "$VAR='$VAL'"; done | egrep "^($_CATALINER_CONFIGURABLES_REGEX)="`
		if [ x"$PROPS_SVC" != x ]; then
			PROPS_SVC=`echo "$PROPS_SVC" | sed s/\"\'$/\'/ | sed s/=\'\"/=\'/`
			echo "===== Importing Cataliner SMF variables: SERVICE-level ($CATALINER_SMF_SERVICE)"
			[ x"$CATALINER_DEBUG" != x -a "$CATALINER_DEBUG" != 0 ] && echo "-----" && echo "$PROPS_SVC" && echo "-----"
			incr NUM_CFG_SMF
			eval $PROPS_SVC
		fi

		PROPS_INST=`svccfg -s "$SMF_FMRI" listprop | egrep '^cataliner/' | sed 's/^cataliner\///' | while read VAR TYPE VAL; do echo "$VAR='$VAL'"; done | egrep "^($_CATALINER_CONFIGURABLES_REGEX)="`
		if [ x"$PROPS_INST" != x ]; then
			PROPS_INST=`echo "$PROPS_INST" | sed s/\"\'$/\'/ | sed s/=\'\"/=\'/`
			echo "===== Importing Cataliner SMF variables: INSTANCE-level ($SMF_FMRI)" 
			[ x"$CATALINER_DEBUG" != x -a "$CATALINER_DEBUG" != 0 ] && echo "-----" && echo "$PROPS_INST" && echo "-----"
			incr NUM_CFG_SMF
			eval $PROPS_INST
		fi
	    fi
	fi
}

validateConfigSanity() {
	### Sanity check for variables. "$1" controls level:
	###	EXT	Config data came from external sources:
	###		provide some syntactic checks if applicable, i.e. that 
	###		numbers are digits, booleans are "true":"false",
	###		directory and file names are valid, etc.
	###		If not, log an error and clear the variable.
	###	INT	likewise, but after guessing missing variables for the
	###		managed application type with hardcoded values. 
	###		Set generic pre-set values for empty variables which 
	###		require a value, or log an error and abort.

	### Validate debug flag
	[ x"$CATALINER_DEBUG" = x -o x"$CATALINER_DEBUG" = x- ] && CATALINER_DEBUG=0
	[ "$CATALINER_DEBUG" -ge 0 ] || CATALINER_DEBUG=0

	### Check/Normalize or clear variables according to data types
	validateConfigDataTypes

	if [ "$1" = INT ]; then
		###### Enforce some defaults for values not yet defined
		clearUndefinedVariables

		### If no config file set the lock-file name, set it now according
		### to execution mode: managed app type (pre-set, smf, $0, hardcoded)
		[ x"$LOCK" = x ] && LOCK="/tmp/cataliner_$CATALINER_SCRIPT_APP.lock"

		###### Variants below are disputed: they would not lock a cronjob from
		###### interfering with an init script like '/etc/rc3.d/S99alfresco'
		### ...use script file name. Note that paths to symlinks count.
		#[ x"$LOCK" = x ] && LOCK="/tmp/cataliner_""$CATALINER_SCRIPT_APP"_"$BASENAME".lock
		### ...use script file path+name. Note that paths to symlinks count.
		#[ x"$LOCK" = x ] && LOCK="/tmp/cataliner_""$CATALINER_SCRIPT_APP"_"`echo $0 | sed 's/\//_/g'`".lock

		### Config for waitLog
		[ x"$CATALINER_WAITLOG_FLAG" = x ] && \
			CATALINER_WAITLOG_FLAG="true"
		[ x"$CATALINER_WAITLOG_TIMEOUT" = x ] && \
			CATALINER_WAITLOG_TIMEOUT=600
		[ x"$CATALINER_WAITLOG_TIMEOUT_OPENLOG" = x ] && \
			CATALINER_WAITLOG_TIMEOUT_OPENLOG=60
		[ x"$CATALINER_WAITLOG_INCLUDELAST" = x ] && \
			CATALINER_WAITLOG_INCLUDELAST=0

		[ x"$CATALINER_HARDLOCK_SMF_SLEEP" = x ] && \
			CATALINER_HARDLOCK_SMF_SLEEP=50

		[ x"$CATALINER_REGEX_STARTED" = x ] && \
			CATALINER_REGEX_STARTED='INFO(:? .*Server startup|  .* Started) in .*ms|GlassFish.*startup time.*ms|Application server startup complete'
#			CATALINER_REGEX_STARTED='INFO.*tart.. in .*ms|startup time.*ms|Application server startup complete'
#			CATALINER_REGEX_STARTED='INFO(:? .*Server startup|  .* Started) in .*ms'
#			CATALINER_REGEX_STARTED='(INFO(:? .*Server startup|  .* Started) in .*ms|GlassFish.*startup time.*ms)'
		### This string should match both Tomcat and JBOSS as
		### well as GF (+Sun App Server) logs...

		[ x"$CATALINER_REGEX_STARTING" = x ] && \
			CATALINER_REGEX_STARTING='org.apache.coyote.http...Http..BaseProtocol init|org.apache.coyote.http...Http..Protocol init|JBossTS Transaction Service .JTA version. - JBoss Inc|Starting recovery manager|[Rr]unning [Gg]lass[Ff]ish [Vv]ersion|Starting Sun GlassFish'

		[ x"$CATALINER_REGEX_STOPPING" = x ] && \
			CATALINER_REGEX_STOPPING='org.apache.coyote.http...Http..BaseProtocol destroy|org.apache.coyote.http...Http..Protocol destroy|.org.jboss.system.server.Server. Shutting down the server|[Gg]lass[Ff]ish.*[Ss]erver shutdown initiated|Stopping Sun GlassFish'

		[ x"$CATALINER_REGEX_STOPPED" = x ] && \
			CATALINER_REGEX_STOPPED='INFO: Failed shutdown of Apache Portable Runtime|.org.jboss.system.server.Server. Shutdown complete|[Gg]lass[Ff]ish.*[Ss]hutdown procedure finished|(sun-app|glassfish).*Server shutdown complete'

		[ x"$CATALINER_REGEX_FAILURES" = x ] && \
			CATALINER_REGEX_FAILURES='(^| )(ERROR|SEVERE)[ :]? |STDERR|[Ee]xception'
		### This string should match both Tomcat and JBOSS logs...
		### NOTE: GlassFish errors not yet added explicitly

		[ x"$CATALINER_REGEX_STACKTRACE" = x ] && \
			CATALINER_REGEX_STACKTRACE='^[^ ]*[Ee]xception|^[	 ]+at .+\..+\(.+\)'
		### This string should match both Tomcat and JBOSS logs...
		### Double-accounting is possible for 'xception' lines

		### Define timeouts for 'stopJVM':
		###	First we run the defined stop script and wait (if timerun.sh exists)
		###	If no timerun.sh, this may hang forever...
		[ x"$CATALINER_TIMEOUT_STOP_METHOD" = x ] && \
			CATALINER_TIMEOUT_STOP_METHOD=15
		### Even if successful, these method-scripts often exit after posting a stop
		### command to appserver-management module or sending a kill, and so don't
		### guarantee that the server actually exited (and restarts are in peril). So: 
		###	Then we monitor if the appserver log file is opened by a Java process
		###	If it is still open when a timeout is hit, a kill command is issued
		###	  to the Java process(es) to TERM or KILL them.
		###	If they live up to _ABORT timeout, this script aborts with error.
		[ x"$CATALINER_TIMEOUT_STOP_TERM" = x ] && \
			CATALINER_TIMEOUT_STOP_TERM=15
		[ x"$CATALINER_TIMEOUT_STOP_KILL" = x ] && \
			CATALINER_TIMEOUT_STOP_KILL=90
		[ x"$CATALINER_TIMEOUT_STOP_ABORT" = x ] && \
			CATALINER_TIMEOUT_STOP_ABORT=120

		### Set reasonable minimums from practice
		### KILL and ABORT may be "0" to disable such measures
		[ "$CATALINER_TIMEOUT_STOP_METHOD" -lt "15" ] && \
			CATALINER_TIMEOUT_STOP_METHOD=15
		[ "$CATALINER_TIMEOUT_STOP_TERM" -lt "15" ] && \
			CATALINER_TIMEOUT_STOP_TERM=15
		[  "$CATALINER_TIMEOUT_STOP_KILL" -le "$CATALINER_TIMEOUT_STOP_TERM" \
		-a "$CATALINER_TIMEOUT_STOP_KILL" != 0 \
		] && 	CATALINER_TIMEOUT_STOP_KILL="`add $CATALINER_TIMEOUT_STOP_TERM 15`"
		[ "$CATALINER_TIMEOUT_STOP_ABORT" -le "$CATALINER_TIMEOUT_STOP_KILL" \
		-a "$CATALINER_TIMEOUT_STOP_ABORT" != 0 \
		] && 	CATALINER_TIMEOUT_STOP_ABORT="`add $CATALINER_TIMEOUT_STOP_KILL 5`"

		[ x"$CATALINER_PROBE_POSTSTART_DELAY" = x ] && \
			CATALINER_PROBE_POSTSTART_DELAY=0

		[ x"$CATALINER_PROBE_PRESTART_DELAY" = x ] && \
			CATALINER_PROBE_PRESTART_DELAY=0

		[ x"$CATALINER_PROBE_POSTSTOP_DELAY" = x ] && \
			CATALINER_PROBE_POSTSTOP_DELAY=0

		[ x"$CATALINER_PROBE_PRESTOP_DELAY" = x ] && \
			CATALINER_PROBE_PRESTOP_DELAY=0

		[ x"$CATALINER_PROBE_DEBUG_ALL" = x ] && \
			CATALINER_PROBE_DEBUG_ALL=false

		[ x"$CATALINER_PROBE_DEBUG_PRESTART_LDAP" = x ] && \
			CATALINER_PROBE_DEBUG_PRESTART_LDAP=false

		[ x"$CATALINER_PROBE_DEBUG_PRESTART_DBMS" = x ] && \
			CATALINER_PROBE_DEBUG_PRESTART_DBMS=false

		[ x"$CATALINER_PROBE_DEBUG_PRESTART_HTTP" = x ] && \
			CATALINER_PROBE_DEBUG_PRESTART_HTTP=false

		[ x"$CATALINER_PROBE_DEBUG_POSTSTART_AMLOGIN" = x ] && \
			CATALINER_PROBE_DEBUG_POSTSTART_AMLOGIN=false

		[ x"$CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG" = x ] && \
			CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG="false"

		[ x"$CATALINER_PROBE_PRESTART_LDAP_FLAG" = x ] && \
			CATALINER_PROBE_PRESTART_LDAP_FLAG="false"

		[ x"$CATALINER_PROBE_PRESTART_LDAP_FALLBACK" = x ] && \
			CATALINER_PROBE_PRESTART_LDAP_FALLBACK="true"

		[ x"$CATALINER_PROBE_PRESTART_DBMS_FLAG" = x ] && \
			CATALINER_PROBE_PRESTART_DBMS_FLAG="false"

		[ x"$CATALINER_PROBE_PRESTART_DBMS_FALLBACK" = x ] && \
			CATALINER_PROBE_PRESTART_DBMS_FALLBACK="true"

		[ x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = x ] && \
			CATALINER_PROBE_PRESTART_HTTP_FLAG="false"

		[ x"$CATALINER_PROBE_PRESTART_HTTP_FALLBACK" = x ] && \
			CATALINER_PROBE_PRESTART_HTTP_FALLBACK="true"

		[ x"$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" = x ] && \
			CATALINER_PROBE_PRESTART_LDAP_TIMEOUT="0"
		[ "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" -gt 0 ] 2>/dev/null || \
			CATALINER_PROBE_PRESTART_LDAP_TIMEOUT="0"

		[ x"$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" = x ] && \
			CATALINER_PROBE_PRESTART_DBMS_TIMEOUT="0"
		[ "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" -gt 0 ] 2>/dev/null || \
			CATALINER_PROBE_PRESTART_DBMS_TIMEOUT="0"

		[ x"$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" = x ] && \
			CATALINER_PROBE_PRESTART_HTTP_TIMEOUT="0"
		[ "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" -gt 0 ] 2>/dev/null || \
			CATALINER_PROBE_PRESTART_HTTP_TIMEOUT="0"

		[ x"$CATALINER_NONROOT" = x ] && \
			CATALINER_NONROOT="false"

		[ x"$CATALINER_COREDUMPS_DISABLE" = x ] && 
			CATALINER_COREDUMPS_DISABLE="true"
		[ x"$CATALINER_FILEDESC_LIMIT" = x ] && 
			CATALINER_FILEDESC_LIMIT="65536"

		case "$CATALINER_APPSERVER_NOHUPFILE_WRITE" in
		    false|append|overwrite) ;;
		    yes|true) CATALINER_APPSERVER_NOHUPFILE_WRITE="append" ;;
		    truncate) CATALINER_APPSERVER_NOHUPFILE_WRITE="overwrite" ;;
		    no)	CATALINER_APPSERVER_NOHUPFILE_WRITE="false";;
		    *)	CATALINER_APPSERVER_NOHUPFILE_WRITE="false";;
		esac

		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && \
		    case "$CATALINER_SCRIPT_APP" in
			*[Jj][Bb][Oo][Ss][Ss]*)
			    CATALINER_APPSERVER_LOGFILE_RENAME="true" ;;
			*)
			    CATALINER_APPSERVER_LOGFILE_RENAME="false" ;;
		    esac
	fi
}

validateConfigDataTypes() {
	### For config variables listed as having a certain expected type,
	### run some checks to validate the value or set it to empty string
	[ x"$CATALINER_DEBUG" = x -o x"$CATALINER_DEBUG" = x- ] && CATALINER_DEBUG=0
	[ "$CATALINER_DEBUG" -ge 0 ] || CATALINER_DEBUG=0

	for VAR in $_CATALINER_CONFIGURABLES_BOOLEAN; do
		eval VAL="\$$VAR"
		case "$VAL" in
			[yY][eE][sS]|[tT][rR][uU][eE]|[yY]|1)
				eval $VAR="true" ;;
			[nN][oO]|[fF][aA][lL][sS][eE]|[nN]|0)
				eval $VAR="false" ;;
			-|"") ;;
			*)
				[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid BOOLEAN value '\$$VAR'='$VAL'" >&2
				eval $VAR="" ;;
		esac
	done

	for VAR in $_CATALINER_CONFIGURABLES_INTEGER; do
		eval VAL="\$$VAR"
		case "$VAL" in
			-|"") ;;
			*.*)
				[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid INTEGER value '\$$VAR'='$VAL'" >&2
				eval $VAR=""
				;;
			*)
				/usr/bin/test "$VAL" -le 0 -o "$VAL" -ge 0
				if [ $? != 0 ]; then
					[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid INTEGER value '\$$VAR'='$VAL'" >&2
					eval $VAR=""
				else
					TEST="`add "$VAL" 0`"
					eval $VAR="$TEST"
				fi
				;;
		esac
	done

	for VAR in $_CATALINER_CONFIGURABLES_PATH_FILE; do
		eval VAL="\$$VAR"
		case "$VAL" in
			-|"") ;;
			*)
				if [ ! -s "$VAL" -o ! -r "$VAL" ]; then
					[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid PATH_FILE value '\$$VAR'='$VAL'" >&2
					eval $VAR=""
				fi
				;;
		esac
	done

	for VAR in $_CATALINER_CONFIGURABLES_PATH_PROGRAM; do
		eval VAL="\$$VAR"
		case "$VAL" in
			-|"") ;;
			*)
				if [ ! -s "$VAL" -o ! -x "$VAL" ]; then
					[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid PATH_PROGRAM value '\$$VAR'='$VAL'" >&2
					eval $VAR=""
				fi
				;;
		esac
	done

	for VAR in $_CATALINER_CONFIGURABLES_PATH_DIR; do
		eval VAL="\$$VAR"
		case "$VAL" in
			-|"") ;;
			*)
				if [ ! -d "$VAL" -o ! -r "$VAL" -o ! -x "$VAL" ]; then
					[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing invalid PATH_DIR value '\$$VAR'='$VAL'" >&2
					eval $VAR=""
				fi
				;;
		esac
	done
}

clearUndefinedVariables() {
	### clear ("-" -> "") the forced-undefined variables from the list

	for VAR in $_CATALINER_CONFIGURABLES; do
		eval VAL="\$$VAR"
		if [ x"`echo $VAL | sed 's/ //g'`" = x"-" ]; then
			[ "$CATALINER_DEBUG" -gt 0 ] && echo "WARN: clearing forced-unset value '\$$VAR'='$VAL'" >&2
			eval $VAR=""
		fi
	done
}

########################################################################
### Routines to work with SMF parameter extraction ([Open]Solaris only)
### and to get current user's UID number (Linux/OpenSolaris/Solaris)
### and to change current user's UID if requested by configuration.

getUID() {
	### Returns the numerical UID of current user or of username in
	### parameter $1 - if any.
	### Linux and OpenSolaris boast a more functional "id" than
	### Solaris 10 (u6 - u8), use either one which works.
	NUM_UID="`id -u $1 2>/dev/null`" || NUM_UID="`id $1 | sed 's/uid=\([^(]*\)(\([^)]*\).*$/\1/'`"
	RET=$?

	### So there was no user by this name ($1). Maybe it was UID already?
	if [ x"$RET" != x0 -a x"$1" != x ]; then
		NUM_UID="`add "$1" 0 2>/dev/null`"
		### Empty if error = NaN, same as '$1' if number

		if [ x"$NUM_UID" = x"$1" ]; then
			### Numeric UID was passed. Is it defined in system?
			_TEST="`getent passwd | awk -F: '( $3 == "'"$NUM_UID"'" ) { print $1 }'`"
			[ x"$_TEST" != x ]
			RET=$?
		fi
	fi

	echo "$NUM_UID"
	return $RET
}

### If current user differs from SMF 'method_context/user',
### or from configured CATALINER_NONROOT_USERNAME, try using 'su'.
### Implemented as variable RUNAS="run_as UserName" ($RUNAS cmd params)
### and RUNAS_EVAL "cmd params > output" for user-or-root exec with redirects

run_as() {
    ### Executes parameters $2..$N in context of user named "$1"
    ### Exports LANG=C LC_ALL=C unless _RUNJVM=yes is set; then exports
    ### CATALINER_LANG, CATALINER_LC_ALL, JAVA_HOME, JAVA_OPTS, CATALINA_OPTS
	if [ $# -le 1 ]; then
	    echo "ERROR: At least 2 params needed for run_as()!" >&2
	    return 1
	fi

	RUNAS_USER="$1"
	shift

	if [ "$CATALINER_DEBUG" -ge 1 -o x"$CATALINER_DEBUG_RUNAS" != x ]; then
		echo "INFO: Running '($*)' in context of '$RUNAS_USER'..." >&2
	fi
	### TODO: if "su" causes problems, this can be expanded to some
	### OS-specific techniques like sudo, pfexec, or RBAC?..

	### Running as another user via 'su' may cause echoing of shell
	### greetings. We don't want them in property values, etc. so
	### we redirect stderr/stdout to temp file handles.
	#    su - "$RUNAS_USER" -c "$*"
	#( su - "$RUNAS_USER" -c " ($*) 2>&4 1>&3" ) 3>&1 4>&2 1>/dev/null 2>/dev/null
        if [ x"$_RUNJVM" = xyes ]; then
                OVERLANG=""
                [ x"$CATALINER_LANG" != x ] && OVERLANG="export LANG; LANG='$CATALINER_LANG';"
                [ x"$CATALINER_LC_ALL" != x ] && OVERLANG="$OVERLANG export LC_ALL; LC_ALL='$CATALINER_LC_ALL';"
                ( su - "$RUNAS_USER" -c " ( $OVERLANG JAVA_OPTS='$JAVA_OPTS'; CATALINA_OPTS='$CATALINA_OPTS'; JAVA_HOME='$JAVA_HOME'; export JAVA_OPTS CATALINA_OPTS JAVA_HOME; $*) 2>&4 1>&3" ) 3>&1 4>&2 1>/dev/null 2>/dev/null
        else
		### Inherit user's env for system commands, but set C locale
                ( su - "$RUNAS_USER" -c " (LANG=C; LC_ALL=C; export LANG LC_ALL; $*) 2>&4 1>&3" ) 3>&1 4>&2 1>/dev/null 2>/dev/null
        fi
}

set_run_as() {
######################################################################
### Set the 'RUNAS' variable if needed, or leave empty for no 'su'.
### This is used when calling external programs:
###	touch - when creating lock-files (owned by unprivileged user if set up)
###	kill  - stopping JVM brutally
###	start/stop - call original startup/shutdown scripts
###	agents - execution of prerequisite checks
###
### Derive from: SMF service set-up or from config environment variables
### CATALINER_NONROOT="true" and CATALINER_NONROOT_USERNAME="username"
###
### NOTE: this currently relies on "su", which requires entering a password
###	if invoked by a non-root user (even if to "su" into himself).
### TODO: allow use by non-root executors via RBAC, sudo, pfexec, etc.
### TODO: when comparing current user and "su" user IDs, test not only
###	names, but also UID numbers (if names differ) to avoid calling "su".
###	However, try to do this once and not in every run_as() call!
###
### Scenarios:
### 1) Running as init script only (no matching SMF instance located):
###	a* If env.vars are set in config, and if CATALINER_NONROOT_USERNAME
###	  differs from current user name - use them for RUNAS.
###	  (NOTE: if current user is not root, "su" will ask for password; user
###	  may treat this as error and abort to reconfigure, or some future
###	  version of cataliner will suggest another method to change account)
###	b* If env.vars are not set, or point to current user - empty RUNAS
### 2) Running as SMF script (SMF_FMRI is set):
###	a* If current user is root, and env.vars are set, use env.vars -
###	  then SMF service runs as root, to execute an unprivileged server,
###	  i.e. to simplify service conversion between SMF and INIT modes.
###	b* If current user (from SMF exec) is non-root, and env.vars are set,
###	  and differ from current user name - abort as config error.
###	c* If env.vars are not set - empty RUNAS (use current user ID)
### 3) Running as init script with located matching SMF instance (initRunSMF):
###	a* If SMF instance has a configured non-root user (not empty, not root,
###	  not zero UID) and current user is root and env.vars are not set via
###	  config - initialize these env.vars with SMF instance's user name
###	  and use them in RUNAS (for lock-files, test agents, etc).
###	b* If SMF instance has a configured non-root user and env.vars are set
###	  via config, and names differ - report error, set RUNAS to SMF user
###	  if current user is not SMF user (i.e. if current user is root)
###	  (if current user is not root, "su" will ask for pass, user can abort)
###	c* If SMF instance has a configured non-root user and env.vars are set
###	  via config, and names/UIDs match and are not current user - set RUNAS
###	d* If SMF instance user is not configured, or is root, and env.vars
###	  are set, and point not to current user name - set RUNAS to env.vars
###	e* If SMF instance user is not configured, or is root, and env.vars 
###	  are not set or if env.vars point to current user - empty RUNAS

	### Pre-set common variables (i.e. current user info)
	RUNAS=""

	CURR_USER="`id | awk '{ print $1 }' | sed 's/^.*(\(.*\))$/\1/'`"
	RES1=$?
	if [ $RES1 = 0 ]; then
		### Currently, we default to current UID which executes
		### this script.
		SMF_USER_DEFAULT="$CURR_USER"
	else
		SMF_USER_DEFAULT="root"
	fi
	CURR_USER_ID="`getUID`"
	RES2=$?
	if [ $RES1 != 0 -o $RES2 != 0 ]; then
		echo "ERROR: problem determining current user name or ID!" >&2
		echo "    Got name = '$CURR_USER' ($RES1), UID = '$CURR_USER_ID' ($RES2)." >&2
		return 3
	fi


	### TODO: do more than just this imported SMF check
	# GETPROPARG_QUIET=true get_run_as_SMF_FMRI >/dev/null 2>/dev/null || RUNAS=""

	SMF_USER_AVAILABLE="false"
	SMF_USER_ACTUAL=""
	SMF_USER=""
	SMF_USER_ID=""

	### CATALINER_NONROOT_USERNAME=...
	### CATALINER_NONROOT="true|false"

	### Non-empty value means that flag is true and value is OK
	NONROOT_USER_ID=""
	if [ x"$CATALINER_NONROOT_USERNAME" != x -a \
	     x"$CATALINER_NONROOT_USERNAME" != x- -a \
	     x"$CATALINER_NONROOT" = xtrue \
	]; then
		NONROOT_USER_ID="`getUID ${CATALINER_NONROOT_USERNAME}`"
		if [ $? != 0 ]; then
			echo "ERROR: configured to run as user '${CATALINER_NONROOT_USERNAME}' but can't determine UID (got '$NONROOT_USER_ID')!" >&2
			return 4
		fi
		if [ x"$NONROOT_USER_ID" = x0 ]; then
			echo "WARN: configured to run as user '${CATALINER_NONROOT_USERNAME}' but UID resolves to 0 (root)!" >&2
		fi
	fi

	case "$_CATALINER_SCRIPT_FRAMEWORK" in
		init)
			### if true = (1a), else = (1b)
			if [ x"$NONROOT_USER_ID" != x \
			  -a x"$NONROOT_USER_ID" != x"$CURR_USER_ID" \
			]; then
				RUNAS="run_as ${CATALINER_NONROOT_USERNAME}"
			fi
			;;
		smf)
			GETPROPARG_QUIET=true get_run_as_SMF_FMRI >/dev/null && \
				SMF_USER_AVAILABLE="true"

			if [ x"$SMF_USER_AVAILABLE" != x"true" ]; then
				echo "ERROR: strange problem getting SMF context user credentials. See above..." >&2
			fi

			### Now we may have variables with SMF user-names:
			### SMF_USER_ACTUAL SMF_USER SMF_USER_ID

			if [ x"$CURR_USER_ID" = x0 \
			  -a x"$NONROOT_USER_ID" != x \
			  -a x"$NONROOT_USER_ID" != x"$CURR_USER_ID" \
			]; then
				### (2a)
				RUNAS="run_as ${CATALINER_NONROOT_USERNAME}"
			fi

			if [ x"$CURR_USER_ID" != x0 \
			  -a x"$NONROOT_USER_ID"  != x \
			  -a x"$NONROOT_USER_ID"  != x"$CURR_USER_ID" \
			]; then
				### (2b)
				### TODO: this may change with sudo, pfexec 
				### or RBAC instead of su
				echo "ERROR: configured to run as user '${CATALINER_NONROOT_USERNAME}' (got UID '$NONROOT_USER_ID')," >&2
				echo "    but current user (from SMF context) is '${CURR_USER}' (UID '${CURR_USER_ID}')! Aborting!" >&2
				cleanExit $SMF_EXIT_ERR_CONFIG
			fi

			if [ x"$NONROOT_USER_ID" = x ]; then
				### (2c)
				RUNAS=""
			fi
			;;
		initRunSMF)
			### Should unspecified "method_context/user"
			### mean "root"?
			SMF_USER_DEFAULT="root"

			### Fake SMF_FMRI to get instance or service properties
			SMF_FMRI="$CATALINER_USE_SMF_FMRI"
			export SMF_FMRI
			GETPROPARG_QUIET=true get_run_as_SMF_FMRI >/dev/null && \
				SMF_USER_AVAILABLE="true"
			unset SMF_FMRI

			### Now we may have variables with SMF user-names:
			### SMF_USER_ACTUAL SMF_USER SMF_USER_ID

			if [ x"$SMF_USER_AVAILABLE" = x"true" \
			  -a x"$SMF_USER_ACTUAL" != x \
			  -a x"$SMF_USER_ACTUAL" != x0 \
			  -a x"$SMF_USER_ACTUAL" != xroot \
			  -a x"$SMF_USER" != x \
			  -a x"$SMF_USER" != x0 \
			  -a x"$SMF_USER" != xroot \
			  -a x"$SMF_USER_ID" != x0 \
			]; then
			### If SMF instance has a configured non-root user...

				if [ x"$CURR_USER_ID" = x0 \
				  -a x"$NONROOT_USER_ID" = x \
				]; then
					### (3a)
					echo "INFO: setting CATALINER_NONROOT_USERNAME='$SMF_USER' (SMF context user name) for wrapper..." >&2
					CATALINER_NONROOT_USERNAME="$SMF_USER"
					CATALINER_NONROOT="true"
					RUNAS="run_as ${CATALINER_NONROOT_USERNAME}"
				fi

				if [ x"$NONROOT_USER_ID" != x \
				  -a x"$NONROOT_USER_ID" != x"$SMF_USER_ID" \
				]; then
					### (3b)
					echo "ERROR (non-fatal this time): configured to run as user '${CATALINER_NONROOT_USERNAME}' (got UID '$NONROOT_USER_ID')," >&2
					echo "    but user from SMF context is '${SMF_USER}' (UID '${SMF_USER_ID}')! Will run wrapper as SMF user!" >&2

					# cleanExit $SMF_EXIT_ERR_CONFIG

					if [ x"$CURR_USER_ID" != x"$SMF_USER_ID" ]; then
						echo "INFO: setting RUNAS to '$SMF_USER' (SMF context user name)..." >&2
						RUNAS="run_as ${SMF_USER}"
					fi
				fi

				if [ x"$NONROOT_USER_ID" != x \
				  -a x"$NONROOT_USER_ID" = x"$SMF_USER_ID" \
				  -a x"$CURR_USER_ID"   != x"$SMF_USER_ID" \
				]; then
					### (3c)
					echo "INFO: setting RUNAS to '$SMF_USER' (SMF context user name)..." >&2
					RUNAS="run_as ${SMF_USER}"
				fi

			else
			### If SMF user is not configured or is root...

				if [ x"$NONROOT_USER_ID" != x \
				  -a x"$NONROOT_USER_ID" != x"$CURR_USER_ID" \
				]; then
					### (3d)
					echo "INFO: setting RUNAS to '$CATALINER_NONROOT_USERNAME' (CATALINER_NONROOT_USERNAME)..." >&2
					RUNAS="run_as ${CATALINER_NONROOT_USERNAME}"
				else
					### (3e)
					RUNAS=""
				fi
			fi

			;;
	esac

	if [ "$CATALINER_DEBUG" -ge 1 -o x"$CATALINER_DEBUG_RUNAS" != x ]; then
		echo "---[ RUNAS detection results..."

		echo "=== Framework run mode flag, etc:"
		echo "  _CATALINER_SCRIPT_FRAMEWORK = '$_CATALINER_SCRIPT_FRAMEWORK'"
		echo "  SMF_FMRI		= '$SMF_FMRI'"
		echo "  CATALINER_USE_SMF_FMRI	= '$CATALINER_USE_SMF_FMRI'"

		echo "=== Current user name:"
		echo "  CURR_USER		= '$CURR_USER'"

		echo "=== Configured NONROOT flag and user name, if any:"
		echo "  CATALINER_NONROOT	= '$CATALINER_NONROOT'"
		echo "  CATALINER_NONROOT_USERNAME = '$CATALINER_NONROOT_USERNAME'"

		echo "=== SMF user info:"
		echo "  SMF_USER_DEFAULT     	= '$SMF_USER_DEFAULT'"
		echo "  SMF_USER_ACTUAL (cfg)	= '$SMF_USER_ACTUAL'"
		echo "  SMF_USER (assumed)	= '$SMF_USER'"

		echo "=== Detected UIDs:"
		echo "  CURR_USER_ID		= '$CURR_USER_ID'"
		echo "  SMF_USER_ID		= '$SMF_USER_ID'"
		echo "  NONROOT_USER_ID	= '$NONROOT_USER_ID'"

		echo "=== Resulting command, if any:"
		echo "  RUNAS (command) 	= '$RUNAS'"
		echo "---]"
	fi
}

get_run_as_SMF_FMRI() {
	### Get execution user from SMF parameters
	### Echoes execution user name to stdout
	### and sets RUNAS variable if CURR_USER_ID != SMF_USER_ID

	if [ "$_CATALINER_SMF_AVAIL" != true -o x"$SMF_FMRI" = x ]; then
	    echo "ERROR: get_run_as_SMF_FMRI(): SMF not found!" >&2
	    #RUNAS="" && export RUNAS
	    return 1
	fi

	### Which user is assumed to execute SMF methods for this instance?
	### TODO: research if there may be different credentials in contexts
	###	for stop/start/restart/default methods?
	SMF_USER_ACTUAL="` GETPROPARG_QUIET=false getproparg method_context/user `"
	if [ $? = 0 -a x"$SMF_USER_ACTUAL" != x ]; then
		SMF_USER="$SMF_USER_ACTUAL"
	else
		echo "INFO: Defaulting not defined SMF_USER to '$SMF_USER_DEFAULT'" >&2
		SMF_USER="$SMF_USER_DEFAULT"
	fi

	SMF_USER_ID="`getUID "$SMF_USER"`"
	if [ $? = 0 ]; then
	    ### No error getting an ID
	    if [ x"$SMF_USER_ID" = x"$SMF_USER" ]; then
		### Got a numeric UID value in SMF, convert to name
		SMF_USER="`getent passwd | awk -F: '( $3 == "'"$SMF_USER_ID"'" ) { print $1 }' | head -1`"
		echo "INFO: numeric UID was passed in SMF property 'method_context/user'='$SMF_USER_ID'." >&2
		echo "      I think it is account of '$SMF_USER' ..." >&2
	    fi

	    if [ x"$CURR_USER_ID" != x"$SMF_USER_ID" ]; then
		RUNAS="run_as $SMF_USER" && export RUNAS
		echo "$SMF_USER_ID"
		return 0
	    else
		RUNAS="" && export RUNAS
	    fi
	else
	    echo "ERROR: unknown user name from SMF property 'method_context/user'='$SMF_USER', skipping RUNAS and probably erring further in SMF..." >&2
	    echo "    Possible causes: invalid '$SMF_FMRI' service set-up or ldap/nis/... user-catalog error" >&2
	    echo "$CURR_USER_ID"
	    return 2
	fi

	echo "$CURR_USER_ID"
	return 0
}

### Get parameter from a service instance or its parent service
### RUNAS is fetched above as the current user's ID, and it's important in
### command-line mode (i.e. real user = root, runas = non-root)
GETPROPARG_QUIET=false
GETPROPARG_INHERIT=true
getproparg() {
	if [ "$_CATALINER_SMF_AVAIL" != true -o x"$SMF_FMRI" = x ]; then
	    echo "ERROR: getproparg(): SMF not found!" >&2
	    return 1
	fi

	if [ x"$GETPROPARG_QUIET" = x"true" ]; then
	    val="`$RUNAS svcprop -p "$1" "$SMF_FMRI" 2>/dev/null`"
	else
	    val="`$RUNAS svcprop -p "$1" "$SMF_FMRI"`"
	fi

	[ -n "$val" ] && echo "$val" && return

	if [ x"$GETPROPARG_INHERIT" = xfalse ]; then
	    false
	    return
	fi

	### Value not defined/set for instance
	### Fetch one set for SMF service defaults
	if [ x"$GETPROPARG_QUIET" = x"true" ]; then
	    val="`$RUNAS svcprop -p "$1" "$CATALINER_SMF_SERVICE" 2>/dev/null`"
	else
	    val="`$RUNAS svcprop -p "$1" "$CATALINER_SMF_SERVICE"`"
	fi

	if [ -n "$val" ]; then
	    [ x"$GETPROPARG_QUIET" != x"true" ] && echo "INFO: Using service-general default attribute '$1' = '$val'" >&2
	    echo "$val"
	    return
	fi
	false
}

######################################################################
### Work with lock-files
_CATALINER_LOCK_CREATED=false
checkLock() {
	### Test if a hard or soft lock file exists.
	### If yes - block (abort)
	### If no - create a new soft lock file
	if [ -f "$LOCK.hard" -a x"$CATALINER_SKIP_HARDLOCK" != x"true" ]; then
	    echo "___ HARD-locked by file '$LOCK.hard'. Bye."

	    if [ x"$SMF_FMRI" != x ]; then
		    echo "INFO: Sleeping now, so that SMF service won't fail on frequent restarts."
		    echo "INFO: After some time ($CATALINER_HARDLOCK_SMF_SLEEP), will try to start again (via SMF revival of service)."
		    sleep $CATALINER_HARDLOCK_SMF_SLEEP
	    fi

	    cleanExit 0
	fi

	if [ -f "$LOCK" ]; then
	    OLDPID=`head -n 1 "$LOCK"`
	    TRYOLDPID=`$PSEF_CMD | grep -v grep | awk '{ print $2 }' | grep "$OLDPID"`
	    if [ x"$TRYOLDPID" != x ]; then
		echo "___ Locked by file '$LOCK' (PID=$TRYOLDPID). Bye."
		$PSEF_CMD | grep -v grep | grep "$TRYOLDPID"
		cleanExit 0
	    fi
	    $RUNAS rm -f "$LOCK"
	fi

	$RUNAS_EVAL "echo $$ > '$LOCK'" && _CATALINER_LOCK_CREATED=true
	$RUNAS_EVAL "echo '`date`:
CATALINER_SCRIPT_APP:		$CATALINER_SCRIPT_APP
_CATALINER_APPTYPE_CMDNAME:	$_CATALINER_APPTYPE_CMDNAME
\$0 \$@:  			$0 $@
_CATALINER_APPTYPE_SMFFMRI:	$_CATALINER_APPTYPE_SMFFMRI
SMF_FMRI:			$SMF_FMRI
CATALINER_USE_SMF_FMRI:  	$CATALINER_USE_SMF_FMRI
RUNAS_EVAL:			$RUNAS_EVAL
= Lock execution user:
`id`
`who am i 2>/dev/null`
= Lock effective user:' >> '$LOCK'"

	$RUNAS_EVAL "id >> '$LOCK'"
}

clearLock() {
	### Remove the lock file if it points to current process
	### or is known to have been created by it
	if [ -f "$LOCK" ]; then
	    OLDPID=`head -n 1 "$LOCK"`
	    if [ x"$OLDPID" = x"$$" -o "$_CATALINER_LOCK_CREATED" = "true" ]; then
		$RUNAS rm -f "$LOCK"
		return $?
	    fi

	    TRYOLDPID=`$PSEF_CMD | grep -v grep | awk '{ print $2 }' | grep "$OLDPID"`
	    if [ x"$TRYOLDPID" != x ]; then
		echo "___ Locked by file '$LOCK' (PID=$TRYOLDPID). Can't clear lock."
		$PSEF_CMD | grep -v grep | grep "$TRYOLDPID"
		return 127
	    fi
	    $RUNAS rm -f "$LOCK"
	    return $?
	fi
	return 0
}

checkLockHard() {
	### Test if a hard lock file exists.
	### If yes - block (abort)
	### If no - create a new hard lock file
	if [ -f "$LOCK.hard" -a x"$CATALINER_SKIP_HARDLOCK" != x"true" ]; then
	    echo "___ HARD-locked by file '$LOCK.hard'. Bye."
	    cleanExit 0
	fi

	$RUNAS_EVAL "echo $$ > '$LOCK.hard'"
	$RUNAS_EVAL "echo '`date`:
CATALINER_SCRIPT_APP:		$CATALINER_SCRIPT_APP
_CATALINER_APPTYPE_CMDNAME:	$_CATALINER_APPTYPE_CMDNAME
\$0 \$@:  			$0 $@
_CATALINER_APPTYPE_SMFFMRI:	$_CATALINER_APPTYPE_SMFFMRI
SMF_FMRI:			$SMF_FMRI
CATALINER_USE_SMF_FMRI:  	$CATALINER_USE_SMF_FMRI
RUNAS_EVAL:			$RUNAS_EVAL
= Lock execution user:
`id`
`who am i 2>/dev/null`
= Lock effective user:' >> '$LOCK.hard'"

	$RUNAS_EVAL "id >> '$LOCK.hard'"
}

clearLockHard() {
	### Remove a hard-lock file if it exists
	if [ -f "$LOCK.hard" ]; then
	    $RUNAS rm -f "$LOCK.hard"
	    return $?
	fi
	return 0
}

######################################################################
### Log file monitoring

waitLogCheck() {
	### checks prerequisites for waitLog actions -
	### is it enabled and configured?

	if [ x"$CATALINER_WAITLOG_FLAG" != x"true" ]; then
	    echo "INFO: waitLog disabled by config, not waiting for startup message"
	    return 1
	fi

	if [   x"$CATALINER_APPSERVER_LOGFILE" = x \
	    -o x"$CATALINER_APPSERVER_LOGFILE" = x"-" \
	    -o x"$CATALINER_REGEX_STARTED" = x \
	    -o x"$CATALINER_REGEX_FAILURES" = x \
	    -o x"$CATALINER_REGEX_STACKTRACE" = x \
	]; then
	    echo "INFO: No log file or regexes configured, not waiting for startup message"
	    return 2
	fi

	return 0
}

waitLogOpen() {
	### Waits for the server log file to become opened by a Java process
	### if successful, returns to stdout lines of "ps -ef" output with
	### the found process(es)

	waitLogCheck >&2
	RET=$?
	case $RET in
#	    1|2) return 0;;
	    0) ;;
	    *) return $RET;;
	esac

	### Reasonable time for JVM to start...
	MAXWAIT=60
	if [   x"$CATALINER_WAITLOG_TIMEOUT" != x \
	    -a x"$CATALINER_WAITLOG_TIMEOUT" != x"-" \
	    -a "$CATALINER_WAITLOG_TIMEOUT" -gt 0 \
	]; then
	    MAXWAIT="$CATALINER_WAITLOG_TIMEOUT"
	fi

	if [   x"$CATALINER_WAITLOG_TIMEOUT_OPENLOG" != x \
	    -a x"$CATALINER_WAITLOG_TIMEOUT_OPENLOG" != x"-" \
	    -a "$CATALINER_WAITLOG_TIMEOUT_OPENLOG" -gt 0 \
	]; then
	    MAXWAIT="$CATALINER_WAITLOG_TIMEOUT_OPENLOG"
	fi

	case "$_CATALINER_SCRIPT_OS" in
		SunOS) ### Usual AWK segfaults on long regex lines, which is possible
		    NAWK="nawk" ;;
		Linux) NAWK="awk" ;;
		*) NAWK="awk" ;;
	esac

	echo "===== INFO: waitLogOpen($$): waiting up to $MAXWAIT sec for a JVM to open the log file..." >&2
	COUNT=0
	while [ "$COUNT" -le "$MAXWAIT" ]; do
	    ### We expect this log file to be open by a java process
	    LOG_PIDS="`fuser "$CATALINER_APPSERVER_LOGFILE" 2>/dev/null`"
	    if [ x"$LOG_PIDS" != x ]; then
		LOG_PIDS_RE="`echo $LOG_PIDS | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  / /g' | sed 's/ /|/g'`"
		LOG_PROGS_JAVA="`$PSEF_CMD | $NAWK '$2 ~ /^'"$LOG_PIDS_RE"$/' { print $0 }' | egrep 'java|jre|jdk|jvm'`"
		if [ x"$LOG_PROGS_JAVA" != x ]; then
		    ### the 'ps -ef' output with found java progs,
		    ### caller may do anything with the line(s).
		    echo "$LOG_PROGS_JAVA"
		    [ "$COUNT" -ge 2 ] && echo "===== INFO: waitLogOpen($$): log opened by a JVM after $COUNT sec" >&2
		    return 0
		fi
	    fi
	    incr COUNT || COUNT=0
#	    COUNT="`echo $COUNT+1 | bc`" || COUNT=0
	    sleep 1
	done

	### timed out, if applicable
	echo "===== ERROR: waitLogOpen($$): timer expired. JVM not born?" >&2
	return 3
}

waitLog() {
	### Waits for a line matching the REGEX to appear in FILE
	### Some (under-configured) servers can start so quickly,
	### that if we try to first waitLogOpen() and then start the
	### tail|awk filter, we miss the server startup (few msec).
	### So we must start the tail first, then wait for open...

	TIMERUN_CMD=""
        if [ -x /opt/COSas/bin/timerun.sh ]; then
            MAXWAIT=60
            if [   x"$CATALINER_WAITLOG_TIMEOUT" != x \
                -a x"$CATALINER_WAITLOG_TIMEOUT" != x"-" \
                -a "$CATALINER_WAITLOG_TIMEOUT" -gt 0 \
            ]; then
                MAXWAIT="$CATALINER_WAITLOG_TIMEOUT"
            fi

            if [   x"$CATALINER_WAITLOG_TIMEOUT_OPENLOG" != x \
                -a x"$CATALINER_WAITLOG_TIMEOUT_OPENLOG" != x"-" \
                -a "$CATALINER_WAITLOG_TIMEOUT_OPENLOG" -gt 0 \
            ]; then
                incr MAXWAIT "$CATALINER_WAITLOG_TIMEOUT_OPENLOG"
            else
                incr MAXWAIT 60
            fi

            TIMERUN_CMD="/opt/COSas/bin/timerun.sh $MAXWAIT"
        fi

	case "$_CATALINER_SCRIPT_OS" in
		SunOS) ### Sun awk segfaults or complains on long regexes
			AWK="nawk"
			# AWK="awk -F"
			;;
		Linux)	AWK="awk" ;;
		*) 	AWK="awk" ;;
	esac

	_PID_MAIN=$$

	if [ ! -f "$CATALINER_APPSERVER_LOGFILE" ]; then
		sleep 2
		echo "INFO: the log file '$CATALINER_APPSERVER_LOGFILE' is currently missing; waiting up to $CATALINER_WAITLOG_TIMEOUT_OPENLOG seconds for it to appear"
		I=0
		while [ "$I" -le "$CATALINER_WAITLOG_TIMEOUT_OPENLOG" -a \
			! -f "$CATALINER_APPSERVER_LOGFILE" ]; do
				echodot "_X_ "
				sleep 1
				incr I
		done
		if [ -f "$CATALINER_APPSERVER_LOGFILE" ]; then
			echo " OK: log file is here!"
		else
			echo " FAIL: log file is still not here... trying to continue!"
		fi
		unset I
	fi

	### NOTE: TAIL in interactive 'bash' hung after awk exit, while
	### 'sh' worked as expected. Just in case, try to kill tail.
	( $RUNAS $TIMERUN_CMD tail \
	    -"$CATALINER_WAITLOG_INCLUDELAST"f \
	    "$CATALINER_APPSERVER_LOGFILE"; sleep 1 ) | (

	waitLogOpen
	RET=$?
	[ "$CATALINER_DEBUG" -gt 1 ] && set -x

	case $RET in
	    1|2) RET=0;;
	    0) ### Do the parsing
		echo "===== Monitoring log file '$CATALINER_APPSERVER_LOGFILE'"
		echo "===== for startup regex '$CATALINER_REGEX_STARTED' "
		echo "===== counting failure regex '$CATALINER_REGEX_FAILURES' hits"
		echo "===== and stacktrace regex '$CATALINER_REGEX_STACKTRACE' hits"
		if [ x"$TIMERUN_CMD" != x ]; then
		    echo "===== (max $CATALINER_WAITLOG_TIMEOUT seconds)"
		fi


		RET=2
		### awk can fail (RET==2) with long entries, keep it up (lose stats)
		### I don't want to depend on perl as well
		while [ $RET != 0 -a $RET != 127 ]; do
		    $AWK 'BEGIN { m = 127; failhits = 0; stacktracehits = 0 }
/'"$CATALINER_REGEX_STARTED"'/ { m = 0; exit 0 }
/'"$CATALINER_REGEX_FAILURES"'/ { failhits++ }
/'"$CATALINER_REGEX_STACKTRACE"'/ { stacktracehits++ }
END { print "\n\n"$0;
print "Error and Exception lines logged:   ", failhits;
print "Exception stack trace lines logged: ", stacktracehits;
print "\n"; exit m; }' 2>/dev/null
		    RET=$?
		done
		;;
	    *)  #echo "===== ERROR: waitLog(): code $RET" >&2
		#exit $RET
		;;
	esac

	_FILTER_PIDS="$_PID_MAIN"
        for _PID in "$PID_TAIL_REDIRLOG" "$WAITLOG_PID" "$SMF_LOG_PID"; do
            [ x"$_PID" != x -a -d "/proc/$_PID" ] && \
		_FILTER_PIDS="$_FILTER_PIDS|$_PID"
        done
	_FILTER_PIDS="^($_FILTER_PIDS)"'$'
        unset _PID

	if [ -x /opt/COSas/bin/proctree.sh ]; then
	    PSEF=`/opt/COSas/bin/proctree.sh -P $$`
	    TAILPID=`echo "$PSEF" | egrep "timerun.sh|tail -${CATALINER_WAITLOG_INCLUDELAST}f " | awk '{print $2}' | egrep -v "$_FILTER_PIDS"`
	    [ "$CATALINER_DEBUG" -gt 0 ] && \
		echo "INFO: $$ wanna kill[1]: $TAILPID" && \
		echo "$PSEF"
	    [ x"$TAILPID" != x ] && $RUNAS /bin/kill -15 $TAILPID 2>/dev/null
	else
	    PSEF="`$PSEF_CMD | grep -v grep`"
            TAILPID="`echo "$PSEF" | egrep "timerun.sh|tail -${CATALINER_WAITLOG_INCLUDELAST}f " | awk '( $3 == '"$$"' ) { print $2 }' | egrep -v "$_FILTER_PIDS"`"
	    if [ x"$TAILPID" != x ]; then
		[ "$CATALINER_DEBUG" -gt 0 ] && \
		    echo "INFO: $$ wanna kill[2]: $TAILPID" && \
	    	    echo "$PSEF"
		$RUNAS kill -15 $TAILPID 2>/dev/null
	    else
		### bash (linux) has a 2-layer subprocess
		### we can have even more with timerun and su
		[ "$CATALINER_DEBUG" -gt 0 ] && \
	    	    echo "$PSEF"
		echo "$PSEF" | egrep "timerun.sh|tail -${CATALINER_WAITLOG_INCLUDELAST}f " | awk '{ print $2" "$3 }' | while 
		    read T P; do 
                        DOKILL=hz
                        while [ "$DOKILL" = hz ]; do
                            PP="`echo "$PSEF" | awk '( $2 == '"$P"' ) { print $3 }'`"
                            [ x"$PP" = x ] && DOKILL=no
                            [ x"$PP" = x"$$" ] && DOKILL=yes
                            echo "$PP" | egrep "$_FILTER_PIDS" >/dev/null && \
				DOKILL=no
                            P="$PP"
                        done
		        [ "$CATALINER_DEBUG" -gt 0 ] && \
		    	    echo "INFO: $$ wanna kill[3]: $T ($DOKILL)"
                        [ "$DOKILL" = yes ] && $RUNAS kill -15 "$T" 2>/dev/null
		    done
	    fi
	fi
	[ "$CATALINER_DEBUG" -gt 0 ] && \
	    echo "INFO: waitLog() subprocess completed ($RET)"
	exit $RET )
	### Here dies a subprocess
	RET=$?

	unset _PID_MAIN

	echo "INFO: waitLog() completed ($RET)"
	return $RET
}

inspectLog_lastrun() {
### Inspect the log file from its end digging into the past, trying to find
### the entry about starting the application server. Print stats about logged
### failures during current/last lifetime, start (and stop) time, uptime...
	INSPECT_LOGFILE="$CATALINER_APPSERVER_LOGFILE"
	[ $# = 1 ] && INSPECT_LOGFILE="$1"
	[ x"$INSPECT_DEPTH" = x ] && INSPECT_DEPTH=1

	if [   x"$INSPECT_LOGFILE" = x \
	    -o x"$INSPECT_LOGFILE" = x"-" \
	    -o x"$CATALINER_REGEX_STOPPING" = x \
	    -o x"$CATALINER_REGEX_STOPPED" = x \
	    -o x"$CATALINER_REGEX_STARTING" = x \
	    -o x"$CATALINER_REGEX_STARTED" = x \
	    -o x"$CATALINER_REGEX_FAILURES" = x \
	    -o x"$CATALINER_REGEX_STACKTRACE" = x \
	]; then
	    echo "ERROR: No log file or regexes configured, can not inspect logs."
	    return 2
	fi

	if [   ! -f "$INSPECT_LOGFILE" \
	    -o ! -r "$INSPECT_LOGFILE" \
	]; then
	    echo "ERROR: Log file '$INSPECT_LOGFILE' is not accessible, can not inspect logs."
	    return 2
	fi

	case "$_CATALINER_SCRIPT_OS" in
		SunOS) ### Usual AWK segfaults on long regex lines, which is possible
		    NAWK="nawk"
		    ;;
		Linux) NAWK="awk" ;;
		*) NAWK="awk" ;;
	esac

	### We expect this log file to be open by a java process
	LOG_PIDS="`fuser "$INSPECT_LOGFILE" 2>/dev/null`"
	if [ x"$LOG_PIDS" != x ]; then
	    LOG_PIDS_RE="`echo $LOG_PIDS | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  / /g' | sed 's/ /|/g'`"
	    LOG_PROGS_JAVA="`$PSEF_CMD | $NAWK '$2 ~ /^'"$LOG_PIDS_RE"$/' { print $0 }' | egrep 'java|jre|jdk|jvm'`"
	    if [ x"$LOG_PROGS_JAVA" != x ]; then
		### the 'ps -ef' output with found java progs,
		### caller may do anything with the line(s).
		echo "===== INFO: log '$INSPECT_LOGFILE' is currently used by JVM:"
		echo "$LOG_PROGS_JAVA"
	    fi
	fi

	echo "===== INFO: Inspecting log file '$INSPECT_LOGFILE' (up to $INSPECT_DEPTH server lifetimes):"
	echo ""; echo ""

	revlines "$INSPECT_LOGFILE" | (

	[ "$CATALINER_DEBUG" -gt 1 ] && set -x

	COUNT_STARTS=0
	RET=2
	### awk can fail (RET==2) with long entries, keep it up (lose stats)
	### I don't want to depend on perl as well
	while [ $RET != 127 -a "$COUNT_STARTS" -lt "$INSPECT_DEPTH" ]; do
	    $NAWK 'BEGIN { m = 127; failhits = 0; stacktracehits = 0; startinghits = 0; startedhits = 0; stoppedhits = 0; stoppinghits = 0; prevline = ""; numlines=0;}
/'"$CATALINER_REGEX_STARTING"'/ { startingTS="= "$0"\n= "prevline; startinghits++; m = 0; exit 0 }
/'"$CATALINER_REGEX_STOPPED"'/  { stoppedTS="= "$0"\n= "prevline; stoppedhits++ }
/'"$CATALINER_REGEX_STOPPING"'/ { stoppingTS="= "$0"\n= "prevline; stoppinghits++ }
/'"$CATALINER_REGEX_STARTED|org.apache.catalina.startup.Catalina start"'/  { startedTS="= "$0"\n= "prevline; startedhits++ }
/'"$CATALINER_REGEX_FAILURES"'/ { failhits++ }
/'"$CATALINER_REGEX_STACKTRACE"'/ { stacktracehits++ }
prevline=$0;
numlines++;
END {
print "==== Server began starting ("startinghits"):\n"	startingTS;
print "==== Server has started ("startedhits"):\n"	startedTS;
print "==== Server began stopping ("stoppinghits"):\n"	stoppingTS;
print "==== Server has stopped ("stoppedhits"):	\n"	stoppedTS;
print "==== Error and Exception lines logged:  	"	failhits;
print "==== Exception stack trace lines logged:	"	stacktracehits;
print "==== Total number of lines checked:		"	numlines;
exit m; }' 2>/dev/null
	    RET=$?
	    # echo "=($RET)"
	    [ $RET = 0 ] && echo "===== This was $COUNT_STARTS lifetimes ago..." && echo "=" && echo "=" && incr COUNT_STARTS
	done | egrep '^='
	exit $RET )
	### Here dies a subprocess
}

renameLog() {
	if [   x"$CATALINER_APPSERVER_LOGFILE_RENAME" = xtrue \
	    -a x"$CATALINER_APPSERVER_LOGFILE" != x \
	    -a x"$CATALINER_APPSERVER_LOGFILE" != x"-" \
	    -a -f "$CATALINER_APPSERVER_LOGFILE" \
	]; then
	    COUNT=1
	    TS="`date +%Y-%m-%d`"
	    while [ -f "$CATALINER_APPSERVER_LOGFILE.$TS-$COUNT" ]; do
		incr COUNT
	    done
	    echo "=== INFO: Renaming appserver log file to '$CATALINER_APPSERVER_LOGFILE.$TS-$COUNT'"
	    mv -f "$CATALINER_APPSERVER_LOGFILE" "$CATALINER_APPSERVER_LOGFILE.$TS-$COUNT"
	fi
}

######################################################################
### Prerequisite environment sanity probes

### These routine probe prerequisite conditions, if any are defined
probePreStart() {
	RL="`getRunLevel`"
	if [ "$RL" != run ]; then
		echo "System not in running state ($RL). Won't start '$0'!"
		getRunLevel DEBUG
		cleanExit $SMF_EXIT_OK
	fi

	### Check if the server is not already running
	if probeIsAlreadyRunning ; then
		echo "ERROR: A JVM is already running (see info above). Aborting now!" >&2
		cleanExit $SMF_EXIT_OK
	fi

	probeDelay "$CATALINER_PROBE_PRESTART_DELAY" "before startup dependency probes" || cleanExit $SMF_EXIT_ERR_FATAL

	probeldap || cleanExit $SMF_EXIT_ERR_FATAL
### TODO later: really implement probedbms_*
###		(jisql client, detect db settings?)
	probedbms || cleanExit $SMF_EXIT_ERR_FATAL
### TODO later: probefilesys (COSas agents for free space, reachability, etc.)
	probehttp || cleanExit $SMF_EXIT_ERR_FATAL

	true
}

probePostStart() {
	probeDelay "$CATALINER_PROBE_POSTSTART_DELAY" "after JVM startup" || cleanExitStop $SMF_EXIT_ERR_FATAL
	probeamlogin || cleanExitStop $SMF_EXIT_ERR_FATAL
	true
}

probePreStop() {
	probeDelay "$CATALINER_PROBE_PRESTOP_DELAY" "before JVM shutdown" || cleanExit $SMF_EXIT_ERR_FATAL
	true
}

probePostStop() {
	probeDelay "$CATALINER_PROBE_POSTSTOP_DELAY" "after JVM shutdown" || cleanExit $SMF_EXIT_ERR_FATAL
	true
}

### Actual probing routines
probeDelay() {
	### Simply waits after startup before running other probes
	###   $1	delay timeout (works if >0 seconds)
	###   $2	reason (i.e. "after JVM startup")
	if [   x"$1" != x \
	    -a x"$1" != x- ] \
	&& [ "$1" -gt 0 ]; then
	    echo "=== A delay of $1 seconds was configured $2..."
	    sleep $1
	fi
	return 0
}

probeIsAlreadyRunning() {
	### Returns 0 if there is a JVM accessing the server's log file
	### or if there is not enough configurations data to decide.
	### Prints JVM process info to stdout.

	( CATALINER_WAITLOG_FLAG=true
	  CATALINER_WAITLOG_TIMEOUT=1
	  CATALINER_WAITLOG_TIMEOUT_OPENLOG=1
	  CATALINER_REGEX_STARTED=123
	  CATALINER_REGEX_FAILURES=123
	  CATALINER_REGEX_STACKTRACE=123
	  export CATALINER_WAITLOG_FLAG CATALINER_WAITLOG_TIMEOUT CATALINER_REGEX_STARTED CATALINER_REGEX_FAILURES CATALINER_REGEX_STACKTRACE
	  waitLogOpen 2>/dev/null )
	RET=$?

	case $RET in
	    1|2) # echo "Log file info not configured" >&2
		return $SMF_EXIT_OK;;
	    0) return $SMF_EXIT_OK;;
	    *) #echo "Applicable JVM not found ($RET)" >&2
		return $SMF_EXIT_ERR_FATAL;;
	esac
}

###############################################################
### LDAP probes

probeldap_default_settings() {
	### Before starting some appservers we should ensure LDAP is up.
	### Guess required parameters if they were not explicitly configured.
	[ x"$CATALINER_PROBE_PRESTART_LDAP_FLAG" = xfalse ] && return 0

	[ x"$CATALINER_PROBE_PRESTART_LDAP_FLAG" = x ] && CATALINER_PROBE_PRESTART_LDAP_FLAG="true"
	[ x"$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" = x ] && CATALINER_PROBE_PRESTART_LDAP_TIMEOUT="0"
	[ "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" -gt 0 ] 2>/dev/null || CATALINER_PROBE_PRESTART_LDAP_TIMEOUT="0"
	if [ x"$CATALINER_PROBE_PRESTART_LDAP_METHOD" = x ]; then
	    case "`which ldapsearch 2>&1`" in
		/*)	CATALINER_PROBE_PRESTART_LDAP_METHOD="probeldap_ldapsearch" ;;
		which*|no*|""|*)
			CATALINER_PROBE_PRESTART_LDAP_METHOD="probeldap_tcpip_probe" ;;
	    esac
	fi

	#[ x"$CATALINER_PROBE_PRESTART_LDAP_HOST" = x ] && CATALINER_PROBE_PRESTART_LDAP_HOST="dps"
	[ x"$CATALINER_PROBE_PRESTART_LDAP_HOST" = x ] && CATALINER_PROBE_PRESTART_LDAP_HOST="ldap"
	[ x"$CATALINER_PROBE_PRESTART_LDAP_PORT" = x ] && CATALINER_PROBE_PRESTART_LDAP_PORT="389"
}

probeldap_tcpip_probe() {
	### Check LDAP server accessibility by trying to connect to its port
	### Returns 0 if no error, non-0 if has problems connecting
	if [ ! -x "/opt/COSas/bin/agent-tcpip.sh" ]; then
		echo "ERROR: '/opt/COSas/bin/agent-tcpip.sh' not found, skipping LDAP TCP/IP probe!" >&2
		return 0
	fi

	### Tries to connect to a certain LDAP server's IP and PORT
	### and just enter some blank lines. Can we connect in 3 sec?
	( for N in 1 2 3 4 5 6 7 8 9 0; do echo ""; done ) | \
	/opt/COSas/bin/agent-tcpip.sh 3 \
	    "$CATALINER_PROBE_PRESTART_LDAP_HOST" \
	    "$CATALINER_PROBE_PRESTART_LDAP_PORT" 2>/dev/null 1>&2
}

probeldap_ldapsearch() {
	### Tries to connect to a certain LDAP server's IP and PORT
	### and successfully run an anonymous query
	### Returns 0 if no error, non-0 if has problems connecting
	ldapsearch \
	    -h "$CATALINER_PROBE_PRESTART_LDAP_HOST" \
	    -p "$CATALINER_PROBE_PRESTART_LDAP_PORT" \
	    -b "$CATALINER_PROBE_PRESTART_LDAP_BASEDN" \
	    ${CATALINER_PROBE_PRESTART_LDAP_USER:+-D\ "$CATALINER_PROBE_PRESTART_LDAP_USER"} \
	    ${CATALINER_PROBE_PRESTART_LDAP_PASS:+-w\ "$CATALINER_PROBE_PRESTART_LDAP_PASS"} \
	    ${CATALINER_PROBE_PRESTART_LDAP_PASSFILE:+-j\ "$CATALINER_PROBE_PRESTART_LDAP_PASSFILE"} \
	    "$CATALINER_PROBE_PRESTART_LDAP_FILTER" dn 2>/dev/null 1>&2
	RES=$?

	[ x"$RES" = x0 ] && return 0

	### If this method was requested but misconfigured,
	### it will fail. On another hand, we can quickly catch 
	### problems like server-side password changes...
	if [ "$RES" != 0 -a x"$CATALINER_PROBE_PRESTART_LDAP_FALLBACK_TCP" = xfalse ]; then
	    return $RES
	fi

	echo "INFO: probeldap_ldapsearch() failed; falling back to probeldap_tcpip_probe()"
	probeldap_tcpip_probe
}

probeldap() {
	### LDAP-probing method selector
	### Returns 0 if no error, non-0 if has problems connecting
	[ x"$CATALINER_PROBE_PRESTART_LDAP_FLAG" = xtrue ] && \
	[ x"$CATALINER_PROBE_PRESTART_LDAP_METHOD" = x -o \
	  x"$CATALINER_PROBE_PRESTART_LDAP_HOST" = x -o \
	  x"$CATALINER_PROBE_PRESTART_LDAP_PORT" = x \
	] && echo "INFO: LDAP settings for probing are not completely set, but probe was requested in config - trying to apply defaults..." \
	  && probeldap_default_settings

	[ x"$CATALINER_PROBE_PRESTART_LDAP_BASEDN" = x ] && \
	    CATALINER_PROBE_PRESTART_LDAP_BASEDN='cn=schema'
	[ x"$CATALINER_PROBE_PRESTART_LDAP_FILTER" = x ] && \
	    CATALINER_PROBE_PRESTART_LDAP_FILTER='(objectclass=*)'

	if [   x"$CATALINER_PROBE_PRESTART_LDAP_METHOD" != x \
	    -a x"$CATALINER_PROBE_PRESTART_LDAP_METHOD" != x- \
	    -a x"$CATALINER_PROBE_PRESTART_LDAP_FLAG" = xtrue \
	]; then
		echo_noret "===== Waiting for LDAP Server '$CATALINER_PROBE_PRESTART_LDAP_HOST:$CATALINER_PROBE_PRESTART_LDAP_PORT' (LDAP Probe method = '$CATALINER_PROBE_PRESTART_LDAP_METHOD', max tests: "
		if [ "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" -gt 0 ] 2>/dev/null; then
		    echo_noret "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT"
		else
		    echo_noret "infinitely"
		fi
		echo ")..."

		PROBE_LOG=">/dev/null 2>/dev/null"
		[ x"$CATALINER_PROBE_DEBUG_ALL" = xtrue -o \
		  x"$CATALINER_PROBE_DEBUG_PRESTART_LDAP" = xtrue ] && \
		    PROBE_LOG=""

		RET=1
		COUNT=0
		while [ $RET != 0 ] ; do
		    echodot
		    eval "$CATALINER_PROBE_PRESTART_LDAP_METHOD" $PROBE_LOG
		    RET=$?
		    incr COUNT || COUNT=0
		    if [ $RET != 0 ]; then
			sleep 1
			if [ "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" -gt 0 ]; then
			    if [ "$CATALINER_PROBE_PRESTART_LDAP_TIMEOUT" -le "$COUNT" ]; then
				echo "ERROR: probeldap wait timer expired ($COUNT retries, return code '$RET')!" >&2
				return $RET
			    fi
			fi
		    fi
		done
		echo ""
		echo "===== LDAP seems OK (after $COUNT tests)"
		return 0
	fi

	### Probe not enabled
	return 0
}

###############################################################
### DBMS probes

probedbms_default_settings() {
	### Before starting some appservers we should ensure DBMS is up.
	### Try to guess required parameters if they were not set explicitly.
	[ x"$CATALINER_PROBE_PRESTART_DBMS_FLAG" = xfalse ] && return 0

	[ x"$CATALINER_PROBE_PRESTART_DBMS_FLAG" = x ] && CATALINER_PROBE_PRESTART_DBMS_FLAG="true"
	[ x"$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" = x ] && CATALINER_PROBE_PRESTART_DBMS_TIMEOUT="0"
	[ "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" -gt 0 ] 2>/dev/null || CATALINER_PROBE_PRESTART_DBMS_TIMEOUT="0"
	case "$CATALINER_PROBE_PRESTART_DBMS_ENGINE" in
	    mysql|pgsql|oracle)
		[ x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x ] && \
		    CATALINER_PROBE_PRESTART_DBMS_METHOD="probedbms_${CATALINER_PROBE_PRESTART_DBMS_ENGINE}" ;;
	    "") ;;
	    *)	echo "INFO: Unknown CATALINER_PROBE_PRESTART_DBMS_ENGINE='$CATALINER_PROBE_PRESTART_DBMS_ENGINE' setting!" >&2
		;;
	esac

	### PATH should be properly set by admin at this point...
	### TODO: Detect presence of jisql and suggest it as an option
	###	How to guess db type though?
	[ x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x ] && \
	    case "`which mysql 2>&1`" in
		/*)	CATALINER_PROBE_PRESTART_DBMS_METHOD="probedbms_mysql"
			CATALINER_PROBE_PRESTART_DBMS_ENGINE="mysql"
			;;
	    esac
	[ x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x ] && \
	    case "`which pgsql 2>&1`" in
		/*)	CATALINER_PROBE_PRESTART_DBMS_METHOD="probedbms_pgsql"
			CATALINER_PROBE_PRESTART_DBMS_ENGINE="pgsql"
			;;
	    esac
	[ x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x ] && \
	    case "`which sqlplus 2>&1`" in
		/*)	CATALINER_PROBE_PRESTART_DBMS_METHOD="probedbms_oracle"
			CATALINER_PROBE_PRESTART_DBMS_ENGINE="oracle"
			;;
	    esac
	[ x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x ] && \
			CATALINER_PROBE_PRESTART_DBMS_METHOD="probedbms_tcpip_probe"
		#case dbms_engine ... ?

	[ x"$CATALINER_PROBE_PRESTART_DBMS_HOST" = x ] && CATALINER_PROBE_PRESTART_DBMS_HOST="$CATALINER_PROBE_PRESTART_DBMS_ENGINE"
	[ x"$CATALINER_PROBE_PRESTART_DBMS_PORT" = x ] && case "$CATALINER_PROBE_PRESTART_DBMS_ENGINE" in
	    mysql)
		CATALINER_PROBE_PRESTART_DBMS_PORT="3306" ;;
	    pgsql)
		CATALINER_PROBE_PRESTART_DBMS_PORT="5432" ;;
	    oracle)
		CATALINER_PROBE_PRESTART_DBMS_PORT="1521" ;;
	esac

	[ x"$CATALINER_PROBE_PRESTART_DBMS_ENGINE" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_HOST" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_PORT" = x \
	] && echo "INFO: Could not guess DBMS settings for probing..." \
	  && CATALINER_PROBE_PRESTART_DBMS_FLAG="false"
}

probedbms_tcpip_probe() {
	### Check DBMS server accessibility by trying to connect to its port
	### Returns 0 if no error, non-0 if has problems connecting
	if [ ! -x "/opt/COSas/bin/agent-tcpip.sh" ]; then
		echo "ERROR: '/opt/COSas/bin/agent-tcpip.sh' not found, skipping DBMS TCP/IP probe!" >&2
		return 0
	fi

	### Tries to connect to a certain DBMS server's IP and PORT
	### and just enter some blank lines. Can we connect in 3 sec?
	( for N in 1 2 3 4 5 6 7 8 9 0; do echo ""; done ) | \
	/opt/COSas/bin/agent-tcpip.sh 3 "$CATALINER_PROBE_PRESTART_DBMS_HOST" "$CATALINER_PROBE_PRESTART_DBMS_PORT" 2>/dev/null 1>&2
}

probedbms_jisql() {
	### Tries to connect to a certain DBMS server's IP and PORT
	### and successfully run a simple query, depends on COSjisql
	### and CATALINER_PROBE_PRESTART_DBMS_ENGINE
	### Returns 0 if no error, non-0 if has problems connecting
	### TODO: Implement this DBMS probe

	case "$CATALINER_PROBE_PRESTART_DBMS_ENGINE" in
	    mysql) ### We have a jisql wrapper for this...
	        [ x"$CATALINER_PROBE_PRESTART_DBMS_SQL" = x ] && \
			CATALINER_PROBE_PRESTART_DBMS_SQL='show databases;'
		if [ -x /opt/COSas/bin/mysqlj ]; then
			OUTPUT="`MYSQL_DB="$CATALINER_PROBE_PRESTART_DBMS_DB" \
			MYSQL_HOST="$CATALINER_PROBE_PRESTART_DBMS_HOST" \
			MYSQL_PORT="$CATALINER_PROBE_PRESTART_DBMS_PORT" \
			MYSQL_USER="$CATALINER_PROBE_PRESTART_DBMS_USER" \
			MYSQL_PASS="$CATALINER_PROBE_PRESTART_DBMS_PASS" \
			MYSQL_QUERY="$CATALINER_PROBE_PRESTART_DBMS_SQL" \
			    /opt/COSas/bin/mysqlj 2>&1`"
			RES=$?

			[ x"$RES" = x0 ] && \
			    echo "$OUTPUT" | grep SQLException && RES=1

			[ x"$RES" = x0 ] && echo "$OUTPUT" && return 0

			### If this method was requested but misconfigured,
			### it will fail. On another hand, we can quickly catch 
			### problems like server-side password changes...
			if [ "$RES" != 0 -a x"$CATALINER_PROBE_PRESTART_DBMS_FALLBACK_TCP" = xfalse ]; then
			    return $RES
			fi
		fi
		;;
	esac

	### Fallback variant
	echo "ERROR: probedbms_jisql() is not yet implemented for this database type or was misconfigured"
	#return 0

	echo "Probing with probedbms_tcpip_probe:"
	probedbms_tcpip_probe
}

probedbms_mysql() {
	### Tries to connect to a certain DBMS server's IP and PORT
	### and successfully run a simple query, depends on mysql binaries
	### Returns 0 if no error, non-0 if has problems connecting
	### TODO: Implement this DBMS probe
	echo "ERROR: probedbms_mysql() not yet implemented"
	#return 0

	echo "Probing with probedbms_tcpip_probe:"
	probedbms_tcpip_probe
}

probedbms_pgsql() {
	### Tries to connect to a certain DBMS server's IP and PORT
	### and successfully run a simple query, depends on PostgreSQL binaries
	### Returns 0 if no error, non-0 if has problems connecting
	### TODO: Implement this DBMS probe
	echo "ERROR: probedbms_pgsql() not yet implemented"
	#return 0

	echo "Probing with probedbms_tcpip_probe:"
	probedbms_tcpip_probe
}

probedbms_oracle() {
	### Tries to connect to a certain DBMS server's IP and PORT
	### and successfully run a simple query, depends on Oracle client
	### Returns 0 if no error, non-0 if has problems connecting
	### TODO: Implement this DBMS probe
	echo "ERROR: probedbms_oracle() not yet implemented"
	#return 0

	echo "Probing with probedbms_tcpip_probe:"
	probedbms_tcpip_probe
}

probedbms() {
	### DBMS-probing method selector
	### Returns 0 if no error, non-0 if has problems connecting

	[ x"$CATALINER_PROBE_PRESTART_DBMS_FLAG" = xtrue ] && \
	[ x"$CATALINER_PROBE_PRESTART_DBMS_ENGINE" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_HOST" = x -o \
	  x"$CATALINER_PROBE_PRESTART_DBMS_PORT" = x \
	] && echo "INFO: DBMS settings for probing are not completely set, but probe was requested in config - trying to apply defaults..." \
	  && probedbms_default_settings

	if [   x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" != x \
	    -a x"$CATALINER_PROBE_PRESTART_DBMS_METHOD" != x- \
	    -a x"$CATALINER_PROBE_PRESTART_DBMS_FLAG" = xtrue \
	]; then
		echo_noret "===== Waiting for DBMS Server '$CATALINER_PROBE_PRESTART_DBMS_HOST:$CATALINER_PROBE_PRESTART_DBMS_PORT' (DBMS Probe method = '$CATALINER_PROBE_PRESTART_DBMS_METHOD', max tests: "
		if [ "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" -gt 0 ] 2>/dev/null; then
		    echo_noret "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT"
		else
		    echo_noret "infinitely"
		fi
		echo ")..."

		PROBE_LOG=">/dev/null 2>/dev/null"
		[ x"$CATALINER_PROBE_DEBUG_ALL" = xtrue -o \
		  x"$CATALINER_PROBE_DEBUG_PRESTART_DBMS" = xtrue ] && \
		    PROBE_LOG=""

		RET=1
		COUNT=0
		while [ $RET != 0 ] ; do
		    echodot
		    eval "$CATALINER_PROBE_PRESTART_DBMS_METHOD" $PROBE_LOG
		    RET=$?
		    incr COUNT || COUNT=0
		    if [ $RET != 0 ]; then
			sleep 1
			if [ "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" -gt 0 ]; then
			    if [ "$CATALINER_PROBE_PRESTART_DBMS_TIMEOUT" -le "$COUNT" ]; then
				echo "ERROR: probedbms wait timer expired ($COUNT retries, return code '$RET')!" >&2
				return $RET
			    fi
			fi
		    fi
		done
		echo ""
		echo "===== DBMS seems OK (after $COUNT tests)"
		return 0
	fi

	### Probe not enabled
	return 0
}

###############################################################
### HTTP probes

probehttp_default_settings() {
	### Before starting some appservers we ensure other webapps are up.
	### Try to guess required parameters if they were not set explicitly.
	[ x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = xfalse ] && return 0

	[ x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = x ] && CATALINER_PROBE_PRESTART_HTTP_FLAG="true"
	[ x"$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" = x ] && CATALINER_PROBE_PRESTART_HTTP_TIMEOUT="0"
	[ "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" -gt 0 ] 2>/dev/null || CATALINER_PROBE_PRESTART_HTTP_TIMEOUT="0"

	if [ x"$CATALINER_PROBE_PRESTART_HTTP_METHOD" = x ]; then
	    if [ x"$CATALINER_PROBE_PRESTART_HTTP_PROGRAM" = x ]; then
		CATALINER_PROBE_PRESTART_DBMS_METHOD="probehttp_tcpip_probe"
	    else
		CATALINER_PROBE_PRESTART_DBMS_METHOD="probehttp_program"
	    fi
	fi

	[ x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = xtrue ] && \
	  case x"$CATALINER_PROBE_PRESTART_HTTP_METHOD" in
	    xprobehttp_tcpip_probe)
		[ x"$CATALINER_PROBE_PRESTART_HTTP_HOST" = x ] && \
			CATALINER_PROBE_PRESTART_HTTP_HOST="localhost" && \
			echo "INFO: Guessting HTTP webservice at host $CATALINER_PROBE_PRESTART_HTTP_HOST"
		[ x"$CATALINER_PROBE_PRESTART_HTTP_PORT" = x ] && \
			CATALINER_PROBE_PRESTART_HTTP_PORT="80" && \
			echo "INFO: Guessting HTTP webservice at port $CATALINER_PROBE_PRESTART_HTTP_PORT"
		;;
	    xprobehttp_program)
		case "$CATALINER_PROBE_PRESTART_HTTP_PROGRAM" in
		    "") echo "INFO: MISCONFIGURED HTTP webservice settings for probing: no CATALINER_PROBE_PRESTART_HTTP_PROGRAM value" >&2
			CATALINER_PROBE_PRESTART_HTTP_FLAG="false"
			return 1
			;;
		    /*) [ ! -x "$CATALINER_PROBE_PRESTART_HTTP_PROGRAM" ] && \
			  echo "INFO: MISCONFIGURED HTTP webservice settings for probing: bad CATALINER_PROBE_PRESTART_HTTP_PROGRAM value '$CATALINER_PROBE_PRESTART_HTTP_PROGRAM'" >&2 \
			  && CATALINER_PROBE_PRESTART_HTTP_FLAG="false" && return 1
			true ;;
		    *)	VAL="`which "$CATALINER_PROBE_PRESTART_HTTP_PROGRAM"`"
			case "$VAL" in
			/*) CATALINER_PROBE_PRESTART_HTTP_PROGRAM="$VAL" ;;
			*)
			    echo "INFO: MISCONFIGURED HTTP webservice settings for probing: bad CATALINER_PROBE_PRESTART_HTTP_PROGRAM value '$CATALINER_PROBE_PRESTART_HTTP_PROGRAM' (maybe bad PATH='$PATH' ?)" >&2
			    CATALINER_PROBE_PRESTART_HTTP_FLAG="false"
			    return 1 
			    ;;
			esac
			;;
		esac
		;;
	    x) echo "INFO: Could not guess HTTP webservice settings for probing..." \
		  && CATALINER_PROBE_PRESTART_HTTP_FLAG="false" 
		;;
	esac
}

probehttp_tcpip_probe() {
	### Check HTTP server accessibility by trying to connect to its port
	### Returns 0 if no error, non-0 if has problems connecting
	if [ ! -x "/opt/COSas/bin/agent-web.sh" ]; then
		echo "ERROR: '/opt/COSas/bin/agent-web.sh' not found, skipping HTTP TCP/IP probe!" >&2
		return 0
	fi

	### Tries to connect to a certain HTTP server's IP and PORT
	### and just enter some blank lines. Can we connect in 3 sec?
	( for N in 1 2 3 4 5 6 7 8 9 0; do echo ""; done ) | \
	/opt/COSas/bin/agent-web.sh -t 3 -H \
		-u "$CATALINER_PROBE_PRESTART_HTTP_URL"
		"$CATALINER_PROBE_PRESTART_HTTP_HOST" \
		"$CATALINER_PROBE_PRESTART_HTTP_PORT" 2>/dev/null 1>&2
}

probehttp_program() {
	"$CATALINER_PROBE_PRESTART_HTTP_PROGRAM" $CATALINER_PROBE_PRESTART_HTTP_OPTIONS
	RES=$?

	[ x"$RES" = x0 ] && return 0

	### If this method was requested but misconfigured,
	### it will fail. On another hand, we can quickly catch 
	### problems like server-side password changes...
	if [ "$RES" != 0 -a x"$CATALINER_PROBE_PRESTART_HTTP_FALLBACK_TCP" = xfalse ]; then
	    return $RES
	fi

	echo "INFO: probehttp_program() failed, falling back to probehttp_tcpip_probe()"
	probehttp_tcpip_probe
}

probehttp() {
	### HTTP-probing method selector
	### Returns 0 if no error, non-0 if has problems connecting

	if [ x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = xtrue ]; then
	    RES=0
	    case x"$CATALINER_PROBE_PRESTART_HTTP_METHOD" in
		xprobehttp_tcpip_probe)
		    [ x"$CATALINER_PROBE_PRESTART_HTTP_HOST" = x -o \
		      x"$CATALINER_PROBE_PRESTART_HTTP_PORT" = x ] && RES=1 ;;
		xprobehttp_program)
		    [ x"$CATALINER_PROBE_PRESTART_PROGRAM" = x -o \
		      ! -x "$CATALINER_PROBE_PRESTART_HTTP_PROGRAM" ] && RES=1 ;;
	    esac
	    [ "$RES" = 1 ] && \
		echo "INFO: HTTP webservice settings for probing are not completely set, but probe was requested in config - trying to apply defaults..." \
		&& { probehttp_default_settings || return; }
	fi

	[ x"$CATALINER_PROBE_PRESTART_HTTP_URL" = x ] && \
	    CATALINER_PROBE_PRESTART_HTTP_URL=/

	if [   x"$CATALINER_PROBE_PRESTART_HTTP_METHOD" != x \
	    -a x"$CATALINER_PROBE_PRESTART_HTTP_METHOD" != x- \
	    -a x"$CATALINER_PROBE_PRESTART_HTTP_FLAG" = xtrue \
	]; then
		echo_noret "===== Waiting for HTTP Server (HTTP Probe method = '$CATALINER_PROBE_PRESTART_HTTP_METHOD', max tests: "
		if [ "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" -gt 0 ] 2>/dev/null; then
		    echo_noret "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT"
		else
		    echo_noret "infinitely"
		fi
		if [ "$CATALINER_PROBE_PRESTART_HTTP_METHOD" = probehttp_tcpip_probe ]; then
		    echo_noret ", HTTP server at $CATALINER_PROBE_PRESTART_HTTP_HOST:$CATALINER_PROBE_PRESTART_HTTP_PORT"
		fi
		echo ")..."

		PROBE_LOG=">/dev/null 2>/dev/null"
		[ x"$CATALINER_PROBE_DEBUG_ALL" = xtrue -o \
		  x"$CATALINER_PROBE_DEBUG_PRESTART_HTTP" = xtrue ] && \
		    PROBE_LOG=""

		RET=1
		COUNT=0
		while [ $RET != 0 ] ; do
		    echodot
		    eval "$CATALINER_PROBE_PRESTART_HTTP_METHOD" $PROBE_LOG
		    RET=$?
		    incr COUNT || COUNT=0
		    if [ $RET != 0 ]; then
			sleep 1
			if [ "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" -gt 0 ]; then
			    if [ "$CATALINER_PROBE_PRESTART_HTTP_TIMEOUT" -le "$COUNT" ]; then
				echo "ERROR: probehttp wait timer expired ($COUNT retries, return code '$RET')!" >&2
				return $RET
			    fi
			fi
		    fi
		done
		echo ""
		echo "===== HTTP seems OK (after $COUNT tests)"
		return 0
	fi

	### Probe not enabled
	return 0
}

###############################################################
### AMLOGIN probes

probeamlogin() {
	if [   x"$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" != x \
	    -a x"$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" != x- \
	    -a x"$CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG" = xtrue \
	    -a -x "$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" \
	]; then
	    AMLOGIN_TIMEOUT=""
	    if [ x"$CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT" != x ]; then
		AMLOGIN_TIMEOUT=" -t $CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT"
	    fi

	    PROBE_LOG=">/dev/null 2>/dev/null"
	    [ x"$CATALINER_PROBE_DEBUG_ALL" = xtrue -o \
	      x"$CATALINER_PROBE_DEBUG_POSTSTART_AMLOGIN" = xtrue ] && \
	        PROBE_LOG=""

	    echo "===== Waiting for first login check to complete (may fail because server is still starting)..."
	    echo "# $CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM -n $AMLOGIN_TIMEOUT"
	    eval "$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" -n $AMLOGIN_TIMEOUT $PROBE_LOG
	    RET=$?

	    if [ x"$RET" != x0 ]; then
		echo "===== Sleeping and waiting for second login check to complete (should work)..." && \
		sleep 15 && \
		echo "# $CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM -n $AMLOGIN_TIMEOUT" && \
		eval "$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" -n $AMLOGIN_TIMEOUT $PROBE_LOG
		RET=$?
	    fi

	    return $RET
	fi

	### Probe not enabled
	return 0
}

### Check if runlevel is ok for execution
getRunLevel() {
	RUNLEVEL=`LANG=C LC_ALL=C /usr/bin/who -r | sed 's/^\(.*\)run-level \([^ ]\)\(.*\)$/\2/'`
	OS=`uname -s`

	### Matching patterns for expected OSes:
	### these runlevels mean shutting down
	RUNLEVEL_DOKILL="Linux  06
SunOS   056"

	### these runlevels mean server mode
	RUNLEVEL_DORUN="Linux  345
SunOS   23"

	### if SMF exists, also check runlevels as milestones
	if [ "$_CATALINER_SMF_AVAIL" = "true" ]; then
	    COUNT_RUNNING=0
	    COUNT_MAINT=0
	    COUNT_STOPPED=0
	    COUNT_DISABLED=0
	    COUNT_STARTING=0
	    COUNT_STOPPING=0

	    PREREQ=`/bin/svcs -a | egrep 'svc:/milestone/multi-user:default|svc:/milestone/multi-user-server:default|svc:/milestone/network:default|svc:/milestone/name-services:default|svc:/system/filesystem/local:default'`
	    echo "$PREREQ" | (
	    while read _SMF_STATE _SMF_STIME _SMF_FMRI; do
		[ x"$_SMF_FMRI" != x ] && case "$_SMF_STATE" in
		    'online')	incr COUNT_RUNNING 	|| COUNT_RUNNING=0 ;;
		    'offline*')	incr COUNT_STARTING 	|| COUNT_STARTING=0 ;;
		    'offline')	incr COUNT_STOPPED 	|| COUNT_STOPPED=0 ;;
		    'online*')	incr COUNT_STOPPING 	|| COUNT_STOPPING=0 ;;
		    maint*)	incr COUNT_MAINT 	|| COUNT_MAINT=0 ;;
		    disabled)	incr COUNT_DISABLED	|| COUNT_DISABLED=0 ;;
		    *)		;;
		esac
	    done

	    [ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel SMF inspection:
$PREREQ
COUNT_RUNNING	$COUNT_RUNNING
COUNT_MAINT	$COUNT_MAINT
COUNT_STOPPED	$COUNT_STOPPED
COUNT_DISABLED	$COUNT_DISABLED
COUNT_STARTING	$COUNT_STARTING
COUNT_STOPPING	$COUNT_STOPPING" >&2

	    if [   "$COUNT_RUNNING" -gt 0 \
		-a "$COUNT_STARTING" -ge 0 \
		-a "$COUNT_STOPPED" = 0 \
		-a "$COUNT_DISABLED" -le 2 \
		-a "$COUNT_STOPPING" = 0 \
		-a "$COUNT_MAINT" = 0 \
	    ]; then
		[ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: SMF matched: RUNNING/STARTING" >&2
		echo "run"
		exit 127
	    fi

	    if [   "$COUNT_RUNNING" -ge 0 \
		-a "$COUNT_STARTING" = 0 \
		-a "$COUNT_STOPPED" -ge 0 \
		-a "$COUNT_DISABLED" -ge 0 \
		-a "$COUNT_STOPPING" -ge 0 \
		-a "$COUNT_MAINT" = 0 \
	    ]; then
		[ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: SMF matched: SHUTTING DOWN" >&2
		echo "shut"
		exit 127
	    fi

	    if [   "$COUNT_RUNNING" -ge 0 \
		-a "$COUNT_STARTING" -ge 0 \
		-a "$COUNT_STOPPED" -ge 0 \
		-a "$COUNT_STOPPING" -ge 0 \
	    ]; then
		if [   "$COUNT_DISABLED" -gt 0 \
		    -o "$COUNT_MAINT" -gt 0 \
		]; then
		    [ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: SMF matched: BROKEN" >&2
		    echo "broken"
		    exit 127
		fi
	    fi
	    
	    ### SMF state of prerequisites undetermined, try 'who -r'
	    [ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: SMF not matched: UNDEFINED" >&2
	    exit 0
	    )

	    if [ $? = 127 ]; then
		return 0
	    fi

	    [ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: SMF state not definitive, testing legacy run-levels" >&2
	fi
 
	RLMASK=`echo "$RUNLEVEL_DORUN" | egrep '^'"$OS " | head -1 | awk '{ print $2 }' | grep "$RUNLEVEL"`
	if [ x"$RLMASK" != x ]; then
		[ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: RUNLEVEL '$RUNLEVEL', OS='$OS' matched: RUNNING/STARTING" >&2
		echo "run"
		return 0
	fi

	RLMASK=`echo "$RUNLEVEL_DOKILL" | egrep '^'"$OS " | head -1 | awk '{ print $2 }' | grep "$RUNLEVEL"`
	if [ x"$RLMASK" != x ]; then
		[ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: RUNLEVEL '$RUNLEVEL', OS='$OS' matched: SHUTTING DOWN" >&2
		echo "shut"
		return 0
	fi

	[ x"$1" = xDEBUG ] && echo "DEBUG: getRunLevel: RUNLEVEL '$RUNLEVEL', OS='$OS' not matched: UNDEFINED" >&2
	echo "undef"
	return 0
}

######################################################################
### Routines which do what the user wanted on command line

### Stops the appserver JVM and waits for log file to become closed
stopJVM () {
	echo "=== Stopping..."
	echo "  JAVA_HOME	= $JAVA_HOME"
	if [ x"$JAVA_OPTS" = x ]; then
		[ x"$JAVA_OPTS_COMMON" != x- ] && JAVA_OPTS="$JAVA_OPTS_COMMON"
		[ x"$JAVA_OPTS_STOP" != x- ] && JAVA_OPTS="$JAVA_OPTS $JAVA_OPTS_STOP"

		case "$CATALINER_SCRIPT_APP" in 
			*jboss*)
			[ x"$CATALINA_OPTS" != x- ] && JAVA_OPTS="$JAVA_OPTS $CATALINA_OPTS"
			;;
		esac
	fi

	### Trim surrounding spaces; if the source vars were empty
	### this should leave JAVA_OPTS empty and at discretion of
	### other scripts (run.sh, startup.sh etc.)
	JAVA_OPTS="`echo "$JAVA_OPTS" | sed 's/^ ?\(.*\) $/\1/'`"
	echo "$JAVA_OPTS" | egrep '^ *$' >/dev/null 2>&1 && JAVA_OPTS=""

	CATALINA_OPTS="`echo "$CATALINA_OPTS" | sed 's/^ ?\(.*\) $/\1/'`"
	echo "$CATALINA_OPTS" | egrep '^ *$' >/dev/null 2>&1 && CATALINA_OPTS=""

	### If these vars were requested to be empty (dash), keep them empty
	[ x"$JAVA_OPTS" = x- ] && JAVA_OPTS=" "
	[ x"$CATALINA_OPTS" = x- ] && CATALINA_OPTS=" "

	### Use timerun if available to limit the graceful shutdown routine
	### from hanging indefinitely and proceed to killing timeouts.
	TIMERUN_CMD=""
	[ -x "/opt/COSas/bin/timerun.sh" ] && TIMERUN_CMD="/opt/COSas/bin/timerun.sh $CATALINER_TIMEOUT_STOP_METHOD"

	if [ "$CATALINER_DEBUG" -gt 0 ]; then
		echo "======= Debug: current variables in stopJVM ()"
		set
		echo "======="
		pwd
		echo "======="
	fi

### TODO: Spawn a waitLog like in startJVM to monitor for lines like:
###  Java HotSpot(TM) Server VM warning: Exception java.lang.OutOfMemoryError
###  occurred dispatching signal SIGTERM to handler-
###  the VM may need to be forcibly terminated
### and issue "kill -9" as soon as this condition strikes...

	_EXEC_REDIRECT=""
	[ x"$CATALINER_APPSERVER_NOHUPFILE" != x -a \
	  -d "`dirname "$CATALINER_APPSERVER_NOHUPFILE"`" -a \
	  -w "`dirname "$CATALINER_APPSERVER_NOHUPFILE"`" \
	] && case "$CATALINER_APPSERVER_NOHUPFILE_WRITE" in
		overwrite|append)
			_EXEC_REDIRECT=">> $CATALINER_APPSERVER_NOHUPFILE 2>&1" ;;
	esac

	case "$CATALINER_SCRIPT_APP" in 
		*tomcat*)
			echo "  JAVA_OPTS	= $JAVA_OPTS"
			echo "  CATALINA_OPTS	= $CATALINA_OPTS"
			echo "PWD:  `pwd`"
			if [ x"$CATALINER_APPSERVER_TOMCATCTL" != x -a -x "$CATALINER_APPSERVER_TOMCATCTL" ]; then
			    echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_TOMCATCTL stop $_EXEC_REDIRECT"
			    eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_TOMCATCTL" stop $_EXEC_REDIRECT
			else
			    echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/shutdown.sh $_EXEC_REDIRECT"
			    eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/shutdown.sh $_EXEC_REDIRECT
			fi
			### NOTE that shutdown.sh sends a shutdown message to
			### the Tomcat server as a network interaction.
			### It almost doesn't matter WHO executes the script.
			;;
		*jboss*)
			echo "  JAVA_OPTS	= $JAVA_OPTS"
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/shutdown.sh -S $_EXEC_REDIRECT"
			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/shutdown.sh -S $_EXEC_REDIRECT
			;;
		*glassfish*domain*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin stop-domain $CATALINER_GLASSFISH_ADMINOPTS --domaindir $CATALINER_APPSERVER_VARDIR/domains $CATALINER_GLASSFISH_DOMAIN $_EXEC_REDIRECT"
			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin stop-domain $CATALINER_GLASSFISH_ADMINOPTS --domaindir $CATALINER_APPSERVER_VARDIR/domains $CATALINER_GLASSFISH_DOMAIN $_EXEC_REDIRECT
			;;
		*glassfish*node*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin stop-node-agent $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_NODEAGENT $_EXEC_REDIRECT"
			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin stop-node-agent $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_NODEAGENT $_EXEC_REDIRECT
			;;
		*glassfish*cluster*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin stop-cluster $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_CLUSTER $_EXEC_REDIRECT"
			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin stop-cluster $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_CLUSTER $_EXEC_REDIRECT
			;;
		*glassfish*inst*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin stop-instance $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_INSTANCE $_EXEC_REDIRECT"
			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin stop-instance $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_INSTANCE $_EXEC_REDIRECT
			;;
	esac

	case "$CATALINER_SCRIPT_APP" in 
		*alfresco*)
			PREV_PWD="`pwd`"

			if [ x"$CATALINER_ALF_VIRTUAL" = x"true" ]; then
				[ x"$CATALINER_ALF_HOME" != x -a -d "$CATALINER_ALF_HOME" ] && cd "$CATALINER_ALF_HOME"
				if [ -r ./virtual_stop.sh ]; then
					echo "PWD:  `pwd`"
					echo "EXEC: $RUNAS sh ./virtual_stop.sh"
					_RUNJVM=yes $RUNAS sh ./virtual_stop.sh
				fi
			fi

			if [ x"$CATALINER_ALF_OPENOFFICE" = x"true" ]; then
				[ x"$CATALINER_ALF_HOME" != x -a -d "$CATALINER_ALF_HOME" ] && cd "$CATALINER_ALF_HOME"
				if [ -r ./start_oo.sh ]; then
					case "$_CATALINER_SCRIPT_OS" in
						SunOS)
							echo "EXEC: $RUNAS pkill soffice.bin"
							$RUNAS pkill soffice.bin
							;;
						Linux)
							echo "EXEC: $RUNAS killall soffice.bin"
							$RUNAS killall soffice.bin
							;;
					esac
				fi
			fi

			cd "$PREV_PWD"
			;;
	esac

	if [ -f "$CATALINER_APPSERVER_MONFILE" ]; then
		echo "===== Please wait for server JVM to die (I am monitoring log file $CATALINER_APPSERVER_MONFILE)..."

		CANBREAK="false"
		[ x"`fuser $CATALINER_APPSERVER_MONFILE 2>/dev/null`" != x ] || CANBREAK="true"
		COUNT=0

		PRINTED_JVM_PIDS=n

		case "$_CATALINER_SCRIPT_OS" in
			SunOS) ### Usual AWK segfaults on long regex lines, which is possible
			    NAWK="nawk" ;;
			Linux) NAWK="awk" ;;
			*) NAWK="awk" ;;
		esac

		while [ x"$CANBREAK" = x"false" ]; do
			incr COUNT || COUNT=0
			CANBREAK="true"
			SRVPIDS=""
			SRVPIDS_RE="."
			### Limit fuser output by pre-existing java processes
			### (any processes on first loop), see regex gen below
			for P in `fuser $CATALINER_APPSERVER_MONFILE 2>/dev/null | egrep " ($SRVPIDS_RE)"`; do
				### Check that it's not the user
				case "`ps -e -o pid,comm | grep -w "$P" | grep -v grep`" in
					*java*|*jre*|*jdk*|*jvm*)
						CANBREAK="false"
						SRVPIDS="$SRVPIDS $P"
						;;
				esac
			done

			if [ x"$PRINTED_JVM_PIDS" = xn -a x"$SRVPIDS" != x ]; then
				_W=0
				[ "$CATALINER_TIMEOUT_STOP_ABORT" -gt 0 ] && _W="$CATALINER_TIMEOUT_STOP_ABORT"
				[ "$CATALINER_TIMEOUT_STOP_KILL" -gt 0 ] && _W="$CATALINER_TIMEOUT_STOP_KILL"
				[ "$CATALINER_TIMEOUT_STOP_TERM" -gt 0 ] && _W="$CATALINER_TIMEOUT_STOP_TERM"
				if [ "$_W" -gt 0 ]; then
					echo "=== Waiting on JVM PID(s): $SRVPIDS  for at most $_W seconds before taking rough actions"
				else
					echo "=== Waiting on JVM PID(s): $SRVPIDS"
				fi
				PRINTED_JVM_PIDS=y
				SRVPIDS_RE="`echo "$SRVPIDS" | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  / /g' | sed 's/ /|/g'`"
				$PSEF_CMD | $NAWK '$2 ~ /^'"$SRVPIDS_RE"$/' { print $0 }' | egrep 'java|jre|jdk|jvm'
			fi

			echodot
			sleep 1

			if [ "$COUNT" -gt "$CATALINER_TIMEOUT_STOP_TERM" -a x"$SRVPIDS" != x ]; then
				echo "===== Patience timer expired. $RUNAS TERMing processes ($SRVPIDS)..."
				$RUNAS kill -15 $SRVPIDS
			fi

			if [ "$COUNT" -gt "$CATALINER_TIMEOUT_STOP_KILL" -a x"$SRVPIDS" != x -a "$CATALINER_TIMEOUT_STOP_KILL" -gt 0 ]; then
				echo "===== Patience timer expired. $RUNAS KILLing processes ($SRVPIDS)..."
				$RUNAS kill -9 $SRVPIDS
			fi

			if [ "$COUNT" -gt "$CATALINER_TIMEOUT_STOP_ABORT" -a x"$SRVPIDS" != x -a "$CATALINER_TIMEOUT_STOP_ABORT" -gt 0 ]; then
				echo "===== Patience timer expired. Aborting stop..."
				cleanExit $SMF_EXIT_ERR_FATAL
			fi
		done

		echo ""
		echo "===== It's dead"
	fi

	echo "=== Stopped"
	sleep 3
	renameLog
	echo ""
}

### Starts the appserver JVM and waits for startup message to be logged
startJVM () {
	renameLog
	echo "=== Starting..."
	echo "  JAVA_HOME	= $JAVA_HOME"

	if [ x"$JAVA_OPTS" = x ]; then
		[ x"$JAVA_OPTS_COMMON" != x- ] && JAVA_OPTS="$JAVA_OPTS_COMMON"
		[ x"$JAVA_OPTS_START" != x- ] && JAVA_OPTS="$JAVA_OPTS $JAVA_OPTS_START"
		case "$CATALINER_SCRIPT_APP" in 
			*jboss*)
			[ x"$CATALINA_OPTS" != x- ] && JAVA_OPTS="$JAVA_OPTS $CATALINA_OPTS"
			;;
		esac
	fi

	### Trim surrounding spaces; if the source vars were empty
	### this should leave JAVA_OPTS empty and at discretion of
	### other scripts (run.sh, startup.sh etc.)
	JAVA_OPTS="`echo "$JAVA_OPTS" | sed 's/^ ?\(.*\) $/\1/'`"
	echo "$JAVA_OPTS" | egrep '^ *$' >/dev/null 2>&1 && JAVA_OPTS=""

	CATALINA_OPTS="`echo "$CATALINA_OPTS" | sed 's/^ ?\(.*\) $/\1/'`"
	echo "$CATALINA_OPTS" | egrep '^ *$' >/dev/null 2>&1 && CATALINA_OPTS=""

	### If these vars were requested to be empty (dash), keep them empty
	[ x"$JAVA_OPTS" = x- ] && JAVA_OPTS=" "
	[ x"$CATALINA_OPTS" = x- ] && CATALINA_OPTS=" "

	if [ "$CATALINER_DEBUG" -gt 0 ]; then
		echo "======= Debug: current variables in startJVM ()"
		set
		echo "======="
		pwd
		echo "======="
	fi

	_EXEC_REDIRECT=""
	[ x"$CATALINER_APPSERVER_NOHUPFILE" != x -a \
	  -d "`dirname "$CATALINER_APPSERVER_NOHUPFILE"`" -a \
	  -w "`dirname "$CATALINER_APPSERVER_NOHUPFILE"`" \
	] && case "$CATALINER_APPSERVER_NOHUPFILE_WRITE" in
	        append)	_EXEC_REDIRECT=">> $CATALINER_APPSERVER_NOHUPFILE 2>&1" ;;
		overwrite)
			_EXEC_REDIRECT="> $CATALINER_APPSERVER_NOHUPFILE 2>&1" ;;
	esac

	WAITLOG_PID=""
	JVM_RES=0
	case "$CATALINER_SCRIPT_APP" in 
		*tomcat*)
			echo "  JAVA_OPTS	= $JAVA_OPTS"
			echo "  CATALINA_OPTS	= $CATALINA_OPTS"
			echo "PWD:  `pwd`"
			if [ x"$CATALINER_APPSERVER_TOMCATCTL" != x -a -x "$CATALINER_APPSERVER_TOMCATCTL" ]; then
			    echo "EXEC: eval $RUNAS $CATALINER_APPSERVER_TOMCATCTL start $_EXEC_REDIRECT"
			else
			    echo "EXEC: eval $RUNAS $CATALINER_APPSERVER_BINDIR/startup.sh $_EXEC_REDIRECT"
			fi

			### monitor logfile and PID, and return when server
			### says it's started or broke (and/or timeout is hit)
			waitLog &
			WAITLOG_PID="$!"

			if [ x"$CATALINER_APPSERVER_TOMCATCTL" != x -a -x "$CATALINER_APPSERVER_TOMCATCTL" ]; then
			    eval _RUNJVM=yes $RUNAS "$CATALINER_APPSERVER_TOMCATCTL" start $_EXEC_REDIRECT
			    JVM_RES=$?
			else
			    eval _RUNJVM=yes $RUNAS "$CATALINER_APPSERVER_BINDIR"/startup.sh $_EXEC_REDIRECT
			    JVM_RES=$?
			fi
			;;
		*jboss*)
			echo "  JAVA_OPTS	= $JAVA_OPTS"
			echo "PWD:  `pwd`"
			echo "EXEC: $eval RUNAS nohup $CATALINER_APPSERVER_BINDIR/run.sh -c $JBOSS_CONFIG -b $JBOSS_BINDIP $_EXEC_REDIRECT &"

			### monitor logfile and PID, and return when server
			### says it's started or broke (and/or timeout is hit)
			### NOTE: Unlike tomcat, JBOSS starts a new log file
			waitLog &
			WAITLOG_PID="$!"

			eval _RUNJVM=yes $RUNAS nohup "$CATALINER_APPSERVER_BINDIR"/run.sh -c "$JBOSS_CONFIG" -b "$JBOSS_BINDIP" $_EXEC_REDIRECT &
			JVM_RES=$?
			;;
		*glassfish*domain*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin start-domain $CATALINER_GLASSFISH_ADMINOPTS --domaindir $CATALINER_APPSERVER_VARDIR/domains $CATALINER_GLASSFISH_DOMAIN $_EXEC_REDIRECT"

			waitLog &
			WAITLOG_PID="$!"

			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin start-domain $CATALINER_GLASSFISH_ADMINOPTS --domaindir $CATALINER_APPSERVER_VARDIR/domains $CATALINER_GLASSFISH_DOMAIN $_EXEC_REDIRECT
			#JVM_RES=$?
			JVM_RES=0
			;;
		*glassfish*node*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin start-node-agent $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_NODEAGENT $_EXEC_REDIRECT"

			waitLog &
			WAITLOG_PID="$!"

			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin start-node-agent $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_NODEAGENT $_EXEC_REDIRECT
			#JVM_RES=$?
			JVM_RES=0
			;;
		*glassfish*inst*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin start-instance $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_INSTANCE $_EXEC_REDIRECT"

			waitLog &
			WAITLOG_PID="$!"

			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin start-instance $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_INSTANCE $_EXEC_REDIRECT
			#JVM_RES=$?
			JVM_RES=0
			;;
		*glassfish*cluster*)
			echo "PWD:  `pwd`"
			echo "EXEC: eval $RUNAS $TIMERUN_CMD $CATALINER_APPSERVER_BINDIR/asadmin start-cluster $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_CLUSTER $_EXEC_REDIRECT"

			waitLog &
			WAITLOG_PID="$!"

			eval _RUNJVM=yes $RUNAS $TIMERUN_CMD "$CATALINER_APPSERVER_BINDIR"/asadmin start-cluster $CATALINER_GLASSFISH_ADMINOPTS $CATALINER_GLASSFISH_CLUSTER $_EXEC_REDIRECT
			#JVM_RES=$?
			JVM_RES=0
			;;
	esac

	if [ $JVM_RES != 0 ]; then
		echo "=== Instantly failed ($JVM_RES) to start JVM!" >&2
		kill -15 $WAITLOG_PID 2>/dev/null

	        echo "DIAGS: main log file '$CATALINER_APPSERVER_LOGFILE' ended with lines:"
                echo "---"
		tail -30 "$CATALINER_APPSERVER_LOGFILE"
                echo "---"

		if [ x"$_EXEC_REDIRECT" != x ]; then
		    echo "DIAGS: nohup log file '$CATALINER_APPSERVER_NOHUPFILE' ended with lines:"
		    echo "---"
		    tail -30 "$CATALINER_APPSERVER_NOHUPFILE"
		    echo "---"
		fi

		clearLock
		cleanExit $SMF_EXIT_ERR_FATAL
	else
		echo "=== Server starting..."
	fi

	case "$CATALINER_SCRIPT_APP" in 
		*alfresco*)
			PREV_PWD="`pwd`"

			if [ x"$CATALINER_ALF_VIRTUAL" = x"true" ]; then
				[ x"$CATALINER_ALF_HOME" != x -a -d "$CATALINER_ALF_HOME" ] && cd "$CATALINER_ALF_HOME"
				if [ -r ./virtual_start.sh ]; then
					echo "PWD:  `pwd`"
					echo "EXEC: $RUNAS sh ./virtual_start.sh"
					_RUNJVM=yes $RUNAS sh ./virtual_start.sh
				fi
			fi

			if [ x"$CATALINER_ALF_OPENOFFICE" = x"true" ]; then
				[ x"$CATALINER_ALF_HOME" != x -a -d "$CATALINER_ALF_HOME" ] && cd "$CATALINER_ALF_HOME"
				if [ -r ./start_oo.sh ]; then
					echo "PWD:  `pwd`"
					echo "EXEC: $RUNAS sh ./start_oo.sh"
					_RUNJVM=yes $RUNAS sh ./start_oo.sh
# This script exports the DISPLAY variable to point to an available X11 server
# (i.e. local VNC) and starts OOO networker (cmd valid for Solaris and Linux):
### nohup /opt/openoffice.org3/program/soffice "-accept=socket,host=localhost,port=8100;urp;StarOffice.ServiceManager" "-env:UserInstallation=file:///export/home/oouser" -nologo -headless -nofirststartwizard &

				fi
			fi

			cd "$PREV_PWD"
			;;
	esac

	echo "=== Started JVM, please wait a minute for services..."
	echo "=== You can monitor startup by running:"
	echo "# tail -f $CATALINER_APPSERVER_LOGFILE &"
	echo ""

	RET=$SMF_EXIT_OK
	### Background waitlogs...
	if [ x"$WAITLOG_PID" != x ]; then
	    echo "=== Waiting for logfile startup monitoring ($WAITLOG_PID)..."

	    if [ -d "/proc/$WAITLOG_PID" ]; then
		while sleep 1; do
		    if [ -d "/proc/$WAITLOG_PID" ]; then
			echodot
		    else
			break
		    fi
		done
	    fi &

	    ### How did it end?
	    wait $WAITLOG_PID 2>/dev/null
	    RET=$?

	    echo "=== Log monitoring complete ($RET), exiting startup routine"
	    if [ x"$RET" != x0 ]; then
		RET=$SMF_EXIT_ERR_FATAL

                echo "DIAGS: main log file '$CATALINER_APPSERVER_LOGFILE' ended with lines:"
                echo "---"
                tail -30 "$CATALINER_APPSERVER_LOGFILE"
                echo "---"

		if [ x"$_EXEC_REDIRECT" != x ]; then
		    echo "DIAGS: nohup log file '$CATALINER_APPSERVER_NOHUPFILE' ended with lines:"
		    echo "---"
		    tail -30 "$CATALINER_APPSERVER_NOHUPFILE"
		    echo "---"
		fi
	    fi
	    echo ""
	fi

	### End of startup routine doesn't mean server has no errors, but
	### its process hasn't failed instantly and may even have logged
	### 'Startup in XXX ms' :)
	return $RET
}

###################################################################
### Methods for command-line execution. Either do their job or call svcadm
### and another copy of this script would do the job.
method_stop() {
	### TODO: detect (svcs -p) that the service is not "online",
	### but the JVM is up, and issue a direct classic stop request.

	RET=$SMF_EXIT_OK
	INVOKE="direct"
	if [   x"$CATALINER_USE_SMF_FMRI" != x \
	    -a x"$CATALINER_USE_SMF_FMRI" != x- \
	    -a x"$_CATALINER_SMF_AVAIL" = x"true" \
	    -a x"$SMF_FMRI" = x \
	]; then
		SMF_STATE="`svcs "$CATALINER_USE_SMF_FMRI" | grep "$CATALINER_USE_SMF_FMRI" | awk '{print $1}'`"

		probeIsAlreadyRunning >/dev/null 2>&1
		RUN_STATUS=$?

		INVOKE="svcadm"
		if [ "$RUN_STATUS" = 0 ]; then
			if [ "$SMF_STATE" = "disabled" -o "$SMF_STATE" = maintenance ]; then
				echo "WARNING: SMF service is already disabled or broken, but JVM is running."
				echo "    Will stop directly (as init script)."
				echo "=== Current status:"
				method_status
				echo ""
				INVOKE="direct"
			fi
		fi
	fi

	if [ "$INVOKE" = "svcadm" ]; then
		SMF_LOG="`svccfg -s $CATALINER_USE_SMF_FMRI listprop restarter/logfile | awk '{print $NF}'`"
		SMF_LOG_PID=""
		if [ x"$SMF_LOG" != x -a -f "$SMF_LOG" -a -r "$SMF_LOG" ]; then
			tail -0f "$SMF_LOG" &
			SMF_LOG_PID=$!
		fi

		echo "INFO: calling svcadm disable -st $CATALINER_USE_SMF_FMRI ..."
		svcadm disable -st "$CATALINER_USE_SMF_FMRI"
		RET=$?
		if [ x"$SMF_LOG_PID" != x ]; then
			sleep 1
			echo "INFO: Terminating SMF log monitor thread..."
			kill $SMF_LOG_PID
			sleep 1
		fi
		echo "INFO: svcadm completed ($RET)"

		svcs -p "$CATALINER_USE_SMF_FMRI"
	else
		checkLock "$*"
		probePreStop
		stopJVM
		RET=$?
		probePostStop

		if [ x"$_CATALINER_SCRIPT_OS" = xLinux -a -d /var/lock/subsys -a -f /etc/redhat-release ]; then
		    ### Assume RHEL, use subsys locking
		    subsys="`basename $0 | sed 's/^[SK]..//'`"
		    rm -f "/var/lock/subsys/$subsys"
		fi

		clearLock
	fi

	return $RET
}

method_start() {
	RET=$SMF_EXIT_MON_OFFLINE

	if [   x"$CATALINER_USE_SMF_FMRI" != x \
	    -a x"$CATALINER_USE_SMF_FMRI" != x- \
	    -a x"$_CATALINER_SMF_AVAIL" = x"true" \
	    -a x"$SMF_FMRI" = x \
	]; then
		SMF_LOG="`svccfg -s $CATALINER_USE_SMF_FMRI listprop restarter/logfile | awk '{print $NF}'`"
		SMF_LOG_PID=""
		if [ x"$SMF_LOG" != x -a -f "$SMF_LOG" -a -r "$SMF_LOG" ]; then
			tail -0f "$SMF_LOG" &
			SMF_LOG_PID=$!
		fi

		SMF_STATE="`svcs "$CATALINER_USE_SMF_FMRI" | grep "$CATALINER_USE_SMF_FMRI" | awk '{print $1}'`"
		if [ x"$SMF_STATE" = xmaintenance ]; then
			echo "INFO: Service is in 'maintenance' state. Will 'disable' and 'clear' first"

			echo "INFO: calling svcadm disable -st $CATALINER_USE_SMF_FMRI ..."
			svcadm disable -st "$CATALINER_USE_SMF_FMRI"
			RES=$?
			echo "INFO: svcadm completed ($RES)"

			echo "INFO: calling svcadm clear $CATALINER_USE_SMF_FMRI ..."
			svcadm clear "$CATALINER_USE_SMF_FMRI"
			RES=$?
			echo "INFO: svcadm completed ($RES)"
			sleep 5
			echo ""
		fi

		echo "INFO: calling svcadm enable -st $CATALINER_USE_SMF_FMRI ..."
		svcadm enable -st "$CATALINER_USE_SMF_FMRI"
		RET=$?
		if [ x"$SMF_LOG_PID" != x ]; then
			sleep 1
			echo "INFO: Terminating SMF log monitor thread..."
			kill $SMF_LOG_PID
			sleep 1
		fi
		echo "INFO: svcadm completed ($RET)"

		svcs -p "$CATALINER_USE_SMF_FMRI"
	else
		checkLock "$*"
		probePreStart
		startJVM
		RET=$?
		probePostStart

		[ $RET = 0 ] && if [ x"$_CATALINER_SCRIPT_OS" = xLinux -a -d /var/lock/subsys -a -f /etc/redhat-release ]; then
		    ### Assume RHEL, use subsys locking
		    subsys="`basename $0 | sed 's/^[SK]..//'`"
		    touch "/var/lock/subsys/$subsys"
		fi

		clearLock
	fi

	return $RET
}

method_restart() {
	RET=$SMF_EXIT_MON_OFFLINE

	if [   x"$CATALINER_USE_SMF_FMRI" != x \
	    -a x"$CATALINER_USE_SMF_FMRI" != x- \
	    -a x"$_CATALINER_SMF_AVAIL" = x"true" \
	    -a x"$SMF_FMRI" = x \
	]; then
		SMF_LOG="`svccfg -s $CATALINER_USE_SMF_FMRI listprop restarter/logfile | awk '{print $NF}'`"
		SMF_LOG_PID=""
		if [ x"$SMF_LOG" != x -a -f "$SMF_LOG" -a -r "$SMF_LOG" ]; then
			tail -0f "$SMF_LOG" &
			SMF_LOG_PID=$!
		fi

		SMF_STATE="`svcs "$CATALINER_USE_SMF_FMRI" | grep "$CATALINER_USE_SMF_FMRI" | awk '{print $1}'`"
		if [ x"$SMF_STATE" = xmaintenance ]; then
			echo "INFO: Service is in 'maintenance' state. Will 'disable' and 'clear' first"
		fi

		echo "INFO: calling svcadm disable -st $CATALINER_USE_SMF_FMRI ..."
		svcadm disable -st "$CATALINER_USE_SMF_FMRI"
		RES=$?
		echo "INFO: svcadm completed ($RES)"

		if [ x"$SMF_STATE" = xmaintenance ]; then
			sleep 1
			echo "INFO: calling svcadm clear $CATALINER_USE_SMF_FMRI ..."
			svcadm clear "$CATALINER_USE_SMF_FMRI"
			RES=$?
			echo "INFO: svcadm completed ($RES)"
			sleep 5
			echo ""
		fi

		echo "INFO: calling svcadm enable -st $CATALINER_USE_SMF_FMRI ..."
		svcadm enable -st "$CATALINER_USE_SMF_FMRI"
		RET=$?
		if [ x"$SMF_LOG_PID" != x ]; then
			sleep 1
			echo "INFO: Terminating SMF log monitor thread..."
			kill $SMF_LOG_PID
			sleep 1
		fi
		echo "INFO: svcadm completed ($RET)"

		svcs -p "$CATALINER_USE_SMF_FMRI"
	else
		checkLock "$*"

		probePreStop
		stopJVM
		RET=$?
		probePostStop

		JAVA_OPTS="$ORIG_JAVA_OPTS"

		probePreStart
		startJVM
		RET=$?
		probePostStart

		clearLock
	fi

	return $RET
}

### Prints Java process status (get list of PIDs like in stopJVM or waitLog)
method_status() {
	### print some process info, lock file states
	echo ""
	echo "===== `date`: '$CATALINER_SCRIPT_APP' status info:"

	if [ -s "$LOCK" ]; then
		echo "LOCKED: Run-time lock exists:"
		echo "---"
		cat "$LOCK"
		echo "---"
	fi

	if [ -s "$LOCK.hard" ]; then
		echo "LOCKED: Administrative lock exists:"
		echo "---"
		cat "$LOCK.hard"
		echo "---"
	fi

	if [   x"$CATALINER_USE_SMF_FMRI" != x \
	    -a x"$CATALINER_USE_SMF_FMRI" != x- \
	    -a x"$_CATALINER_SMF_AVAIL" = x"true" \
	    -a x"$SMF_FMRI" = x \
	]; then
		echo "Configured for SMF. Calling svcs -p $CATALINER_USE_SMF_FMRI :"
		echo "---"
		svcs -p "$CATALINER_USE_SMF_FMRI"
		echo "---"
	fi
	if [ x"$_CATALINER_SMF_AVAIL" = x"true" -a x"$SMF_FMRI" != x ]; then
		echo "Called via SMF. Calling svcs -p $SMF_FMRI :"
		echo "---"
		svcs -p "$SMF_FMRI"
		echo "---"
	fi

	echo "JVM process info (who is using log file '$CATALINER_APPSERVER_LOGFILE'):"
	probeIsAlreadyRunning
	RET=$?

	case $RET in
	    1|2) echo "[UNCONF]	Log file info not configured"
		return $SMF_EXIT_OK;;
	    0) echo "[--OK--]	JVM is running"
		return $SMF_EXIT_OK;;
	    *) echo "[-FAIL-]	Applicable JVM not found ($RET)"
		return $SMF_EXIT_ERR_FATAL;;
	esac
}

### End of routines
######################################################################

######################################################################
######
######
######		Actual script logic starts about here...
######
######
######################################################################

######################################################################
###### Prepare playground
###### main() :)

saveOrigVars
detectMath

### General envvars
LANG=C
LC_ALL=C
export LANG LC_ALL

### Set/initialize runtime PATH
PATH_ADD="/usr/xpg4/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin:/usr/local/sbin"
if [ x"$PATH" != x ]; then
    PATH="$PATH:$PATH_ADD"
else
    PATH="$PATH_ADD"
fi
export PATH
unset PATH_ADD

### Set/initialize runtime LD_LIBRARY_PATH
PATH_ADD="/usr/lib:/lib:/usr/local/lib"
if [ x"$LD_LIBRARY_PATH" != x ]; then
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$PATH_ADD"
else
    LD_LIBRARY_PATH="$PATH_ADD"
fi
export LD_LIBRARY_PATH
unset PATH_ADD

######################################################################
###### Determine OS, availability/requirement of SMF, managed app type...

### Which OS features can we expect?
_CATALINER_SCRIPT_OS="`uname -s`" || _CATALINER_SCRIPT_OS="generic"
_CATALINER_SMF_AVAIL="false"
if [   "$_CATALINER_SCRIPT_OS" = "SunOS" \
    -a -s "/lib/svc/share/smf_include.sh" \
    -a -r "/lib/svc/share/smf_include.sh" \
    -a -x "/bin/svcs" \
    -a -x "/bin/svcprop" \
    -a -x "/usr/sbin/svcadm" \
    -a -x "/usr/sbin/svccfg" \
]; then
    _CATALINER_SMF_AVAIL="true"
fi

### How do we inspect process lists (in absense of proctree.sh)?
case "$_CATALINER_SCRIPT_OS" in
    SunOS)	PSEF_CMD="ps -ef" ;;
    Linux)	PSEF_CMD="ps -efwww" ;;
    *)		PSEF_CMD="ps -ef" ;;
esac

### Is this script running from Solaris SMF framework?
###		init | smf | initRunSMF { | other reserved words }
### See below for check that it is configured to run from SMF but is invoked
### manually (mode = initRunSMF) - and cause svcadm invokation for server
### status changes (stop/start/restart). May still run status checks, etc...
_CATALINER_SCRIPT_FRAMEWORK="init"
if [ "$_CATALINER_SMF_AVAIL" = "true" -a x"$SMF_FMRI" != x ]; then
	### if [ x"$_CATALINER_SCRIPT_OS" = x"SunOS" ]
	. /lib/svc/share/smf_include.sh && _CATALINER_SCRIPT_FRAMEWORK="smf"
	CATALINER_SMF_SERVICE="`echo "$SMF_FMRI" | sed 's/^\(.*\:.*\)\(\:.*\)$/\1/'`"
	CATALINER_SMF_INSTANCE="`echo $SMF_FMRI | cut -d: -f3`"

	if [ x"$_ORIG_CATALINER_DEBUG" = x -o x"$_ORIG_CATALINER_DEBUG" = x- ]; then
		### Debug flag was not explicitly set.
		### Try to get one from SMF instance or service
		### If it is not set in SMF, keep auto-set default value.
		GETPROPARG_QUIET=true
		GETPROPARG_INHERIT=true
		export GETPROPARG_INHERIT GETPROPARG_QUIET

		RET="`getproparg cataliner/CATALINER_SCRIPT_APP`" && \
			[ x"$RET" != x -a x"$RET" != x- ] && \
			CATALINER_DEBUG="$RET"
	fi
fi

if [ x"$_CATALINER_SCRIPT_FRAMEWORK" != x"smf" ]; then
	### Set some variables like exit codes to reasonable/standard defaults
	###
	### smf(5) method and monitor exit status definitions
	###	SMF_EXIT_ERR_OTHER, although not defined, encompasses all non-zero
	###	exit status values.
	### see "man smf_method"
	###
	SMF_EXIT_OK=0
	SMF_EXIT_ERR_FATAL=95
	SMF_EXIT_ERR_CONFIG=96
	SMF_EXIT_MON_DEGRADE=97
	SMF_EXIT_MON_OFFLINE=98
	SMF_EXIT_ERR_NOSMF=99
	SMF_EXIT_ERR_PERM=100

	SMF_FMRI=""
	SMF_METHOD="$1"
fi

######################################################################
### Who am I in this run?
### Naming conventions sampled below allow to expand the script
### to running different apps in different web-containers with
### different environment variables, managed by the same Cataliner code
###
### Suggested SMF naming: 'svc:/application/tomcat:opensso' for Tomcat servers,
### 'svc:/application/jboss:livecycle' for JBOSS servers.
######################################################################

######################################################################
### Check SMF FMRI name: $_CATALINER_APPTYPE_SMFFMRI from $SMF_FMRI
### Substring matching may happen by SERVICE or INSTANCE name, i.e.
### 'svc:/application/cataliner:magnolia' or 'svc:/application/magnolia:default'
### would match Magnolia execution mode

### Variable is local, don't inherit. Defines script mode according to SMF_FMRI
_CATALINER_APPTYPE_SMFFMRI=""
case "$SMF_FMRI" in
### TODO EXTENSIBILITY: If a deployment has custom hooks, call them before these built-in defaults here.
	*alf*)	_CATALINER_APPTYPE_SMFFMRI="alfresco-tomcat" ;;
	*magn*)	_CATALINER_APPTYPE_SMFFMRI="magnolia-tomcat" ;;
	*opensso*)
		_CATALINER_APPTYPE_SMFFMRI="opensso-tomcat" ;;
	*jenkins*)
		_CATALINER_APPTYPE_SMFFMRI="jenkins-tomcat" ;;
	*tomcat*)
		_CATALINER_APPTYPE_SMFFMRI="generic-tomcat" ;;
	*adobe*|*livecycle*)
		_CATALINER_APPTYPE_SMFFMRI="livecycle-jboss" ;;
	*jboss*)
		_CATALINER_APPTYPE_SMFFMRI="generic-jboss" ;;
	*glassfish-nodeagent*|*glassfish-na*|*nodeagent*)
		_CATALINER_APPTYPE_SMFFMRI="generic-glassfish-nodeagent" ;;
	*glassfish-domain*|*domain*|*Glass[Ff]ish*)
		_CATALINER_APPTYPE_SMFFMRI="generic-glassfish-domain" ;;
	*glassfish-inst*)
		_CATALINER_APPTYPE_SMFFMRI="generic-glassfish-instance" ;;
	*glassfish-cluster*)
		_CATALINER_APPTYPE_SMFFMRI="generic-glassfish-cluster" ;;
	*glassfish*)
		_CATALINER_APPTYPE_SMFFMRI="generic-glassfish-domain" ;;
esac

######################################################################
### Check script process name: $_CATALINER_APPTYPE_CMDNAME from $0
### Note that '$0' includes both dirname and basename,
### so '/opt/alfresco/cataliner.sh' and '/etc/init.d/alfresco'
### would both point to Alfresco execution mode.

### Variable is local, don't inherit
_CATALINER_APPTYPE_CMDNAME=""
case "$0" in
### TODO EXTENSIBILITY: If a deployment has custom hooks, call them before these built-in defaults here.
	*alf*)	_CATALINER_APPTYPE_CMDNAME="alfresco-tomcat" ;;
	*magn*)	_CATALINER_APPTYPE_CMDNAME="magnolia-tomcat" ;;
	*opensso*)
		_CATALINER_APPTYPE_CMDNAME="opensso-tomcat" ;;
	*jenkins*)
		_CATALINER_APPTYPE_CMDNAME="jenkins-tomcat" ;;
	*tomcat*)
		_CATALINER_APPTYPE_CMDNAME="generic-tomcat" ;;
	*adobe*|*livecycle*)
		_CATALINER_APPTYPE_CMDNAME="livecycle-jboss" ;;
	*jboss*)
		_CATALINER_APPTYPE_CMDNAME="generic-jboss" ;;
	*glassfish-nodeagent*|*glassfish-na*|*nodeagent*)
		_CATALINER_APPTYPE_CMDNAME="generic-glassfish-nodeagent" ;;
	*glassfish-domain*|*domain*|*GlassFish*)
		_CATALINER_APPTYPE_CMDNAME="generic-glassfish-domain" ;;
	*glassfish-inst*)
		_CATALINER_APPTYPE_CMDNAME="generic-glassfish-instance" ;;
	*glassfish-cluster*)
		_CATALINER_APPTYPE_CMDNAME="generic-glassfish-cluster" ;;
	*glassfish*)
		_CATALINER_APPTYPE_CMDNAME="generic-glassfish-domain" ;;
esac

######################################################################
###### Configure managed app type

### The actual variable which determines managed app type for the script
### is CATALINER_SCRIPT_APP. It may have been set externally (env vars)
### or may be set in SMF parameters. Otherwise SMF_FMRI or script name
### will determine the app type. It may finally be overridden in config
### files sourced below, and in SMF parameters overwriting that (again)...

### Try to load a value from this SMF instance
[ x"$CATALINER_SCRIPT_APP" = x- ] && CATALINER_SCRIPT_APP=""
if [ x"$SMF_FMRI" != x -a "$CATALINER_SCRIPT_APP" = x ]; then
	GETPROPARG_QUIET=true
	GETPROPARG_INHERIT=false
	export GETPROPARG_INHERIT GETPROPARG_QUIET
	CATALINER_SCRIPT_APP="`getproparg cataliner/CATALINER_SCRIPT_APP`" || CATALINER_SCRIPT_APP=""
fi

### If application to manage is not pre-set, set it up...
### Ordering: pre-set, SMF_FMRI, $0 app name, hardcoded default
[ x"$CATALINER_SCRIPT_APP" = x- ] && CATALINER_SCRIPT_APP=""
[ x"$CATALINER_SCRIPT_APP" = x ] && CATALINER_SCRIPT_APP="$_CATALINER_APPTYPE_SMFFMRI"
[ x"$CATALINER_SCRIPT_APP" = x ] && CATALINER_SCRIPT_APP="$_CATALINER_APPTYPE_CMDNAME"
[ x"$CATALINER_SCRIPT_APP" = x ] && CATALINER_SCRIPT_APP="magnolia-tomcat"

######################################################################
###### Pre-load variables from config files and SMF overrides
### At this point we may have some variables pre-set in environment,
### but we have not yet really started to use or check them.

loadConfigFiles
loadConfigSMF
[ "$NUM_CFG_FILES" -gt 0 ] && echo "===== INFO: included $NUM_CFG_FILES config files"
[ "$NUM_CFG_SMF" -gt 0 ] && echo "===== INFO: included $NUM_CFG_SMF SMF service/instance config sources"
[ "$NUM_CFG_FILES" = 0 -a "$NUM_CFG_SMF" = 0 ] && echo "=== WARNING: did not include any configuration sources, will guess default config!"
echo ""

validateConfigSanity EXT

### Any not-yet-set variables may be determined in the logic below,
### either according to managed application type or by defaults
### ultimately set in "validateConfigSanity INT"

######################################################################
### Check that if we're running as INIT, there is no corresponding SMF set up.
### If there is, set variable CATALINER_USE_SMF_FMRI to issue "svcadm" calls.
### This variable may also be set explicitly in config file, to avoid guessing.
### May be pre-set to "-" to avoid this check - script should work as INIT.

### Disable anyway, if SMF engine is not available.
[ x"$_CATALINER_SMF_AVAIL" != x"true" ] && CATALINER_USE_SMF_FMRI="-"

### Try to guess the matching SMF instance according to this invokation's
### managed app type ($CATALINER_SCRIPT_APP) - configured or guessed above.
###
### TODO-PERSISTENT: As new app types or typical SMF service names are added,
###	the matching patterns below may need to be expanded!
if [	x"$SMF_FMRI" = x -a \
	x"$CATALINER_USE_SMF_FMRI" = x -a \
	x"$_CATALINER_SMF_AVAIL" = x"true" \
]; then
	_SMF_FAMILY_JBOSS="`svcs -a | grep -v 'lrc:/etc/rc._d/' | egrep -i 'jboss|cataliner' | awk '{print $NF}'`"
	_SMF_FAMILY_TOMCAT="`svcs -a | grep -v 'lrc:/etc/rc._d/' | egrep -i 'tomcat|cataliner' | awk '{print $NF}'`"
	_SMF_FAMILY_GLASSFISH="`svcs -a | grep -v 'lrc:/etc/rc._d/' | egrep -i 'glassfish|/nodeagent|/domain' | awk '{print $NF}'`"
	if [ x"$_SMF_FAMILY_TOMCAT" != x ]; then
		### Some possibly matching SMF service exists...
### TODO EXTENSIBILITY: If a deployment has custom hooks, call them before these built-in defaults here.
		case "$CATALINER_SCRIPT_APP" in
			*alfresco-tomcat*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_TOMCAT | grep -i 'alfresco' | head -1`"
				;;
			*magnolia-tomcat*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_TOMCAT | grep -i 'magnolia' | head -1`"
				;;
			*jenkins-tomcat*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_TOMCAT | grep -i 'jenkins' | head -1`"
				;;
			*opensso-tomcat*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_TOMCAT | grep -i 'opensso' | head -1`"
				;;
			*generic-tomcat*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_TOMCAT | grep -i 'tomcat:default' | head -1`"
				;;
		esac
	fi
	if [ x"$_SMF_FAMILY_JBOSS" != x ]; then
		### Some possibly matching SMF service exists...
		case "$CATALINER_SCRIPT_APP" in
			*livecycle-jboss*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_JBOSS | egrep -i 'livecycle|adobe|alces' | head -1`"
				;;
			*generic-jboss*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_JBOSS | grep -i 'jboss:default' | head -1`"
				;;
		esac
	fi
	if [ x"$_SMF_FAMILY_GLASSFISH" != x ]; then
		### Some possibly matching SMF service exists...
		case "$CATALINER_SCRIPT_APP" in
			*generic-glassfish-nodeagent*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_GLASSFISH | egrep -i 'nodeagent' | head -1`"
				;;
			*generic-glassfish-domain*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_GLASSFISH | egrep -i 'domain' | head -1`"
				;;
			*generic-glassfish*)
				CATALINER_USE_SMF_FMRI="`echo $_SMF_FAMILY_GLASSFISH | grep -i 'glassfish:default' | head -1`"
				;;
		esac
	fi

	if [ x"$CATALINER_USE_SMF_FMRI" != x -a "$CATALINER_DEBUG" -gt 0 ]; then
		echo "DETECTED by INIT-script: SMF instance '$CATALINER_USE_SMF_FMRI'"
	fi
fi

### Below this point we don't guess this value, so forced-empty may be cleared
[ x"$CATALINER_USE_SMF_FMRI" = x- ] && CATALINER_USE_SMF_FMRI=""

if [ x"$SMF_FMRI" = x -a x"$CATALINER_USE_SMF_FMRI" != x -a x"$CATALINER_USE_SMF_FMRI" != x- ]; then
	_CATALINER_SCRIPT_FRAMEWORK="initRunSMF"

	### These vars may be used in getproparg()
	CATALINER_SMF_SERVICE="`echo "$CATALINER_USE_SMF_FMRI" | sed 's/^\(.*\:.*\)\(\:.*\)$/\1/'`"
	CATALINER_SMF_INSTANCE="`echo $CATALINER_USE_SMF_FMRI | cut -d: -f3`"
fi

case "$_CATALINER_SCRIPT_FRAMEWORK" in
	init)	echo "Cataliner framework: Running in INIT-script mode (OS=$_CATALINER_SCRIPT_OS, PID=$$, UID: ${UID:-`id`})" ;;
	smf)	echo "Cataliner framework: Running in SMF-script mode (OS=$_CATALINER_SCRIPT_OS, PID=$$, UID: ${UID:-`id`})" ;;
	initRunSMF)
		echo "Cataliner framework: Running as INIT-wrapper for SMF svc (OS=$_CATALINER_SCRIPT_OS, PID=$$, UID: ${UID:-`id`})"
		echo "WARNING: This script was called in INIT-script mode to manage app type"
		echo "    '$CATALINER_SCRIPT_APP', but a matching SMF instance was detected,"
		echo "    so init-script will actually will use 'svcadm' on SMF service instance"
		echo "    '$CATALINER_USE_SMF_FMRI'."
		;;
esac
echo "Cataliner framework: Script '$0' is (based on) cataliner.sh version:"
echo '    $Id: cataliner.sh,v 1.116 2014/09/10 17:06:00 jim Exp $'
echo ""

if [ x"$SMF_FMRI" = x -a x"$CATALINER_USE_SMF_FMRI" != x -a x"$CATALINER_USE_SMF_FMRI" != x- ]; then
	### Since we now know about relevant SMF service, reload configs.
	### We are especially interested in variables CATALINER_NONROOT and
	### CATALINER_NONROOT_USERNAME to correctly set RUNAS below...

	SMF_FMRI="$CATALINER_USE_SMF_FMRI"
	export SMF_FMRI
	echo "INFO: Reloading config for service '$CATALINER_USE_SMF_FMRI'..."
	loadConfigFiles
	loadConfigSMF
	validateConfigSanity EXT
	echo ""
	unset SMF_FMRI
fi

######################################################################
### Set the 'RUNAS' variable if needed, or leave empty for no 'su'.
### This is used when calling external programs.
### Derived from SMF service set-up or from config environment variables
### CATALINER_NONROOT="true" and CATALINER_NONROOT_USERNAME="username"
### See detailed comments in set_run_as() routine definition, above.

RUNAS=""
set_run_as || RUNAS=""

### Special variable for run_as'ing commands incuding their redirection
### or evaluating them by current shell. Either way, the parameters
### may be single-quoted as one line for further expansion...
RUNAS_EVAL="eval "
[ x"$RUNAS" != x ] && RUNAS_EVAL="$RUNAS "

######################################################################
###### Configure basic JAVA parameters and template config strings

### Choose a JAVA_HOME if not yet provided
if [ x"$JAVA_HOME" = x ]; then
	echo "Choosing JAVA_HOME..."
	### Some typical paths for our Solaris and RHEL setups
	### Path list order matches our preferences in /etc/profile (COSsysr)
	for D in \
		/opt/java \
		/opt/jdk/default \
		/opt/jdk/latest \
		/opt/jdk \
		/usr/java \
		/usr/jdk/default \
		/usr/jdk/latest \
		/usr/java/latest \
		/usr/java/default \
		/usr \
	; do
		[ x"$JAVA_HOME" = x -a -d "$D/bin" -a -x "$D/bin/java" ] && JAVA_HOME="$D"
	done

	echo "Located  JAVA_HOME = '$JAVA_HOME'"
fi

### JVM bitness. Unspecfied (system default), or enforce: "-d32", "-d64"
[ x"$CATALINER_SCRIPT_JVMBITS" = x ] && CATALINER_SCRIPT_JVMBITS=""
### TODO: Determine and use bitness if not preset (isainfo? uname?)...
### TODO: check current kernel and available Java binaries

### Set some default config string snippets
JAVA_OPTS_ENCODING="-Dfile.encoding=UTF-8"
JAVA_OPTS_GCTUNING="-XX:+UseParallelGC -XX:+DisableExplicitGC -XX:ParallelGCThreads=8 -XX:NewRatio=5"
### Include to enable lots of GC logs for debugging
JAVA_OPTS_GCTUNING_DEBUG="-XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+HeapDumpOnOutOfMemoryError"

### TODO: Determine and use memory sizing if not preset...
### TODO: Create java variables branch for startup only
### Pick one depending on server sizing
### 32-bit servers, low RAM/VM
CATALINA_OPTS_32min="-Xmx512M"
CATALINA_OPTS_32low="-Xmx1536M"
### 32-bit servers, average RAM/VM
CATALINA_OPTS_32med="-Xmx3584M"
### >= 4096M req 64-bit servers, much RAM/VM
CATALINA_OPTS_64high="-d64 -Xmx8192M"

CATALINA_OPTS_MEM_DEFAULT="$CATALINA_OPTS_32low"
#CATALINA_OPTS_MEM="default"

### CATALINA_OPTS_MEM may be equaled to one of these default presets above
### (as may be done below for some app types), or may be left empty for
### JVM's own defaults

### TODO: remember why we did this? :)
### Maybe wanted to clear JAVA_OPTS and guess it below?..
if [ x"$JAVA_OPTS" != x -a x"$JAVA_OPTS" != x- ]; then
	### This value won't be overriden by autoconfigs below
	[ x"$JAVA_OPTS_COMMON" != x- ] && \
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			JAVA_OPTS_COMMON="$JAVA_OPTS"
		else
			JAVA_OPTS_COMMON="$JAVA_OPTS $JAVA_OPTS_COMMON"
		fi
fi
export JAVA_OPTS

######################################################################
###### Finish configuration for managed app type by default values,
###### if they were not yes pre-set otherwise

echo "Cataliner framework: Servicing app type '$CATALINER_SCRIPT_APP' action '$1'"

case "$CATALINER_SCRIPT_APP" in 
	### Below we set (or inherit) some execution parameters with values
	### which are default for standard COS&HT application deployments.
	### Parameters which are defined to value "minus" ("-") should not
	### be overwritten by auto-assignment logic. They would then be
	### reset to empty strings before use, see clearUndefinedVariables().
	### Boolean values should use "true" or "false", but for backward
	### compatibility "yes" and "no" should be accepted (and converted).
	*alfresco-tomcat*)
		### NB: in case of SMF, change of identity best done by SMF service
		### In Solaris zone/user/project privileges may be needed to use
		### low ports like http, ftp, cifs...
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="true"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="alfresco"

		[ x"$CATALINER_ALF_HOME" != x -a ! -d "$CATALINER_ALF_HOME" ] && CATALINER_ALF_HOME=""
		[ x"$CATALINER_ALF_HOME" = x -a x"$ALF_HOME" != x -a -d "$ALF_HOME" ] && CATALINER_ALF_HOME="$ALF_HOME"
		[ x"$CATALINER_ALF_HOME" = x ] && CATALINER_ALF_HOME="/opt/alfresco"
		ALF_HOME="$CATALINER_ALF_HOME"
		export ALF_HOME

		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR="$CATALINER_ALF_HOME/tomcat"
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
		if [ x"$CATALINER_WORKDIR" = x -a x"$CATALINER_NONROOT" = x"true" ]; then
			[ x"$CATALINER_NONROOT_USERNAME" != x ] && CATALINER_WORKDIR="`getent passwd "$CATALINER_NONROOT_USERNAME" | awk -F: '{print $6}'`"
			[ x"$CATALINER_WORKDIR" = x -a -d "/export/home/alfresco" ] && CATALINER_WORKDIR="/export/home/alfresco"
			[ x"$CATALINER_WORKDIR" != x -a -d "$CATALINER_WORKDIR/logs" ] && CATALINER_WORKDIR="$CATALINER_WORKDIR/logs"
			[ x"$CATALINER_WORKDIR" != x -a -d "$CATALINER_WORKDIR/log" ] && CATALINER_WORKDIR="$CATALINER_WORKDIR/log"
		fi

		### Note: alfresco dumps its logs here (alfresco-`date`.log)
		if [ x"$CATALINER_WORKDIR" = x -o ! -d "$CATALINER_WORKDIR" ]; then
			CATALINER_WORKDIR="$CATALINER_ALF_HOME"
			[ x"$CATALINER_WORKDIR" != x -a -d "$CATALINER_WORKDIR/logs" ] && CATALINER_WORKDIR="$CATALINER_WORKDIR/logs"
			[ x"$CATALINER_WORKDIR" != x -a -d "$CATALINER_WORKDIR/log" ] && CATALINER_WORKDIR="$CATALINER_WORKDIR/log"
		fi

		### Flags for helper programs. In Alfresco 3.3+ some may also
		### be launched by JVM itself, see alfresco config files.
		[ x"$CATALINER_ALF_OPENOFFICE" = x ] && CATALINER_ALF_OPENOFFICE="true"
		[ x"$CATALINER_ALF_VIRTUAL" = x ] && CATALINER_ALF_VIRTUAL="false"

		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-Xms512m -Xmx2048m -XX:MaxPermSize=256m"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Dalfresco.home=${ALF_HOME}"
			### Special Alfresco script suggestions
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djavax.security.auth.useSubjectCredsOnly=false -Dcom.sun.management.jmxremote"
			### RenderX XEP integration; not a problem if it's not installed
			[ -f "${CATALINER_APPSERVER_DIR}/webapps/alfresco/WEB-INF/xep/xep.xml" ] && \
				JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Dcom.renderx.xep.CONFIG=${CATALINER_APPSERVER_DIR}/webapps/alfresco/WEB-INF/xep/xep.xml"
		fi

		### Enable debugging server
		### Not by default...
		#JAVA_OPTS_START="$JAVA_OPTS_START -Dsun.security.krb5.debug=true -Xdebug -Xrunjdwp:transport=dt_socket,address=2537,suspend=n,server=y"

		### Uncomment to enable lots of GC logs for debugging
		# JAVA_OPTS_START="$JAVA_OPTS_START $JAVA_OPTS_GCTUNING_DEBUG"

		### Following only needed for Sun JVMs before to 1.5 update 8						  
		#JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -XX:CompileCommand=exclude,org/apache/lucene/index/IndexReader\$1,doBody -XX:CompileCommand=exclude,org/alfresco/repo/search/impl/lucene/index/IndexInfo\$Merger,mergeIndexes -XX:CompileCommand=exclude,org/alfresco/repo/search/impl/lucene/index/IndexInfo\$Merger,mergeDeletions"	 
		
		;;

	*magnolia-tomcat*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="tomcat"

		### First try appserver dirs that may have been set up by the admins
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/magnolia/tomcat
#		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/magnolia-enterprise-3.6.3/apache-tomcat-5.5.25
#		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/magnolia-enterprise-4.1/apache-tomcat-5.5.27

		### If that's not available, try guessing from typical
		### dirnames in the bundles. Use "tail" for picking the
		### newest release, if several are available...
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=`ls -1d /opt/magnolia/apache-tomcat*/ 2>/dev/null | tail -1`
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=`ls -1d /opt/magnolia-enterprise-*/apache-tomcat*/ 2>/dev/null | tail -1`
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=`ls -1d /opt/magnolia-*/apache-tomcat*/ 2>/dev/null | tail -1`
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=`ls -1d /opt/*magnolia*/apache-tomcat*/ 2>/dev/null | tail -1`

		### Finally, fail and report this:
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR="/tmp/ERROR/NOT/CONFIGURED.$$"

		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/logs"

		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-Xms64m -Xmx1536M"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			### General settings
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djava.awt.headless=true"
		fi

		### Uncomment to enable lots of GC logs for debugging
		# JAVA_OPTS_START="$JAVA_OPTS_START $JAVA_OPTS_GCTUNING_DEBUG"
		### to enable jmx:
		# CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.port=12345 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
		### to enable debugging:
		# JPDA_OPTS="-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=54455,suspend=n,server=y"
		# export JPDA_OPTS
		;;

	*docflow-tomcat*)
# NOTE: This service block is not exposed to command line and is here
# to provide an example for a more complex configuration including an
# optional dependency on another program and probing prerequisites.
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="tomcat"
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/tomcat
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/logs"

		[ x"$CATALINER_LANG" = x ] && CATALINER_LANG="en_US.UTF-8"
		[ x"$CATALINER_LC_ALL" = x ] && CATALINER_LC_ALL="en_US.UTF-8"

		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-Xms64m -Xmx2048M"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			### General settings
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -XX:MaxPermSize=256m -XX:MinHeapFreeRatio=20 -XX:MaxHeapFreeRatio=40 -XX:NewSize=10m -XX:MaxNewSize=100m "
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djavax.security.auth.useSubjectCredsOnly=false -Dsun.security.krb5.debug=true"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Duser.language=ru -Duser.country=RU"
			### RenderX XEP integration; not a problem if it's not installed
			[ -f "/opt/xep/xep.xml" ] && JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Dcom.renderx.xep.CONFIG=/opt/xep/xep.xml"
		fi

		### Before starting this appserver we should ensure LDAP is up.
		probeldap_default_settings

		### Before starting this appserver we should ensure DBMS is up.
		probedbms_default_settings

		### Uncomment to enable lots of GC logs for debugging
		# JAVA_OPTS_START="$JAVA_OPTS_START $JAVA_OPTS_GCTUNING_DEBUG"
		;;

	*opensso-tomcat*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="tomcat"
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/tomcat
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/logs"

		### Before starting OpenSSO we should ensure LDAP is up.
		probeldap_default_settings

		### After server startup also wait for AMLogin to respond
		### COSas:check-amserver-login script, 
		[ x"$CATALINER_PROBE_POSTSTART_DELAY" = x ] && \
			CATALINER_PROBE_POSTSTART_DELAY=30
		[ x"$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" = x \
		  -a -x "/opt/COSas/bin/check-amserver-login.sh" ] && \
			CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM="/opt/COSas/bin/check-amserver-login.sh"
		[ x"$CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT" = x ] && \
			CATALINER_PROBE_POSTSTART_AMLOGIN_TIMEOUT="240"
		[ x"$CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG" = x \
		  -a -x "$CATALINER_PROBE_POSTSTART_AMLOGIN_PROGRAM" ] && \
			CATALINER_PROBE_POSTSTART_AMLOGIN_FLAG="true"

		[ x"$CATALINER_LANG" = x ] && CATALINER_LANG="en_US.UTF-8"
		[ x"$CATALINER_LC_ALL" = x ] && CATALINER_LC_ALL="en_US.UTF-8"

		### OpenSSO is known to work with just '-Xmx1024m -Dfile.encoding=UTF-8'
		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-Xmx1024M"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			### General settings
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -XX:MaxPermSize=256m -XX:MinHeapFreeRatio=20 -XX:MaxHeapFreeRatio=40 -XX:NewSize=10m -XX:MaxNewSize=100m "
		fi

		### Uncomment to enable lots of GC logs for debugging
		# JAVA_OPTS_START="$JAVA_OPTS_START $JAVA_OPTS_GCTUNING_DEBUG"
		;;
	*jenkins-tomcat*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="jenkins"
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/tomcat
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"

		# Jenkins-specific stuff
		[ x"$JENKINS_HOME" = x ] && JENKINS_HOME=/opt/jenkins
		export JENKINS_HOME

		[ x"$CATALINER_LANG" = x ] && CATALINER_LANG="en_US.UTF-8"
		[ x"$CATALINER_LC_ALL" = x ] && CATALINER_LC_ALL="en_US.UTF-8"
		
		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-Xms64m -Xmx1024M -XX:MaxPermSize=256M -XX:+CMSClassUnloadingEnabled"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			### General settings
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djava.awt.headless=true"
		fi

		JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -DJENKINS_HOME=$JENKINS_HOME"
		#JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djava.util.logging=DEBUG"

		### Set proxy twice: For Jenkins webapp and for CLI tools it may call 
		#JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Dhttp.proxyHost=proxy.myorg.domain -Dhttp.proxyPort=3128"
		#http_proxy="http://proxy.myorg.domain:3128"
		#https_proxy="$http_proxy"
		#ftp_proxy="$http_proxy"
		#export http_proxy https_proxy ftp_proxy

		[ x"$CATALINER_REGEX_STARTED" != 'x-' ] && CATALINER_REGEX_STARTED='INFO:? .*Jenkins is fully up and running'
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/logs"
		;;
	*generic-tomcat*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="tomcat"
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/tomcat
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/logs/catalina.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/logs/tomcat.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/logs"
		;;
	*livecycle-jboss*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="adobe"
		[ x"$JBOSS_CONFIG" = x ] && JBOSS_CONFIG="$CATALINER_JBOSS_CONFIG"
		# [ x"$JBOSS_CONFIG" = x ] && JBOSS_CONFIG="all"
		[ x"$JBOSS_CONFIG" = x ] && JBOSS_CONFIG="lc_mysql"
		[ x"$JBOSS_BINDIP" = x ] && JBOSS_BINDIP="$CATALINER_JBOSS_BINDIP"
		[ x"$JBOSS_BINDIP" = x ] && JBOSS_BINDIP="0.0.0.0"
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=/opt/adobe/jboss
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=/opt/jboss
		[ x"$CATALINER_APPSERVER_DIR" = x -o ! -d "$CATALINER_APPSERVER_DIR" ] && CATALINER_APPSERVER_DIR=/opt/jboss42
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/server.log"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/server.log"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="true"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/jboss.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="overwrite"
		### Note that for some apps the JBOSS Workdir is by default "bin"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log"
		# [ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_BINDIR"

		### Options test for Adobe Livecycle ES2 (v9.0.0.0.2009xxxx)
		### Some defaults ported from their JBOSS's run.sh

		if [ x"$JAVA_OPTS_START" = x ]; then
			[ x"$CATALINA_OPTS_MEM" != x- ] && JAVA_OPTS_START="$CATALINA_OPTS_MEM"
		fi

		if [ x"$JAVA_OPTS_START" = x ]; then
			JAVA_OPTS_START="-d64 -server -Xms1024m -Xmx8192m -XX:PermSize=256m -XX:MaxPermSize=512m"
			JAVA_OPTS_START="$JAVA_OPTS_START $JAVA_OPTS_GCTUNING"
			JAVA_OPTS_START="$JAVA_OPTS_START -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
		fi

#		CATALINER_SCRIPT_JVMBITS=""
#		[ x"$CATALINA_OPTS_MEM" = x ] && CATALINA_OPTS_MEM="-d64 -server -Xms1024m -Xmx8192m -XX:PermSize=256m -XX:MaxPermSize=4096m"
		if [ x"$JAVA_OPTS_COMMON" = x ]; then
			JAVA_OPTS_COMMON="$JAVA_OPTS_ENCODING"
			###JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Dalfresco.home=${ALF_HOME}"
			### Special Alfresco script suggestions
			JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -Djavax.security.auth.useSubjectCredsOnly=false -Dcom.sun.management.jmxremote"

			# Enable Compressed Pointers if supported
			USE_COMPRESSED=`"$JAVA_HOME/bin/java" -XX:+UseCompressedOops 2>&1 | grep "Unrecognized VM option"`
			if [ "x$USE_COMPRESSED" = "x" ]; then
			    JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON -XX:+UseCompressedOops"
			fi
		fi

		;;
	*generic-jboss*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="jboss"
		[ x"$JBOSS_CONFIG" = x ] && JBOSS_CONFIG="$CATALINER_JBOSS_CONFIG"
		[ x"$JBOSS_CONFIG" = x ] && JBOSS_CONFIG="all"
		[ x"$JBOSS_BINDIP" = x ] && JBOSS_BINDIP="$CATALINER_JBOSS_BINDIP"
		[ x"$JBOSS_BINDIP" = x ] && JBOSS_BINDIP="0.0.0.0"
		[ x"$CATALINER_APPSERVER_DIR" = x ] && CATALINER_APPSERVER_DIR=/opt/jboss42
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"
		[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/server.out"
		[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/server.out"
		[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="true"
		[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log/jboss.out"
		[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="overwrite"
		### Note that for some apps the JBOSS Workdir is by default "bin"
		# [ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_DIR/server/$JBOSS_CONFIG/log"
		[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$CATALINER_APPSERVER_BINDIR"
		;;
	*glassfish*)
		### For Glassfish, its own configuration is huge and we don't really
		### want to set any Java settings. Just find where it lives and manage.
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		[ x"$CATALINER_NONROOT_USERNAME" = x ] && CATALINER_NONROOT_USERNAME="glassfish"
		if [ x"$CATALINER_APPSERVER_DIR" = x ]; then
		    for D in `ls -1d /opt/*glassfish* /opt/*/*glassfish* /opt/SUNWappserver* 2>/dev/null | head -1`; do
			[ -d "$D" -a -d "$D/bin" \
			  -a -f "$D/config/asenv.conf" -a -x "$D/bin/asadmin" ] && \
			if [ x"$CATALINER_APPSERVER_DIR" = x \
			  -o x"$CATALINER_APPSERVER_DIR" = x"$D" ]; then
			    CATALINER_APPSERVER_DIR="$D"
			else
			    echo "ERROR: Can't find unambiguous CATALINER_APPSERVER_DIR, please specify!" >&2
			    cleanExit $SMF_EXIT_ERR_CONFIG
			fi
		    done
		fi
		if [ x"$CATALINER_APPSERVER_VARDIR" = x ]; then
		    for D in `ls -1d $CATALINER_APPSERVER_DIR /opt/*glassfish* /opt/*/*glassfish* /opt/SUNWappserver* /var/opt/SUNWappserver* 2>/dev/null | head -1`; do
			[ -d "$D" ] && \
			[ -d "$D/domains" -o -d "$D/nodeagents" ] && \
			if [ x"$CATALINER_APPSERVER_VARDIR" = x \
			  -o x"$CATALINER_APPSERVER_VARDIR" = x"$D" ]; then
			    CATALINER_APPSERVER_VARDIR="$D"
			else
			    echo "ERROR: Can't find unambiguous CATALINER_APPSERVER_VARDIR, please specify!" >&2
			    cleanExit $SMF_EXIT_ERR_CONFIG
			fi
		    done
		fi
		[ x"$CATALINER_APPSERVER_BINDIR" = x ] && CATALINER_APPSERVER_BINDIR="$CATALINER_APPSERVER_DIR/bin"

		### GF server may be "logged in" leaving ~/.asadminpass, or use a pass file:
		# [ x"$CATALINER_GLASSFISH_ADMINOPTS" = x ] && CATALINER_GLASSFISH_ADMINOPTS="--user admin --passwordfile /.as8pass"

		case "$CATALINER_SCRIPT_APP" in
		    *domain*)
			if [ x"$CATALINER_GLASSFISH_DOMAIN" = x ]; then
			    CATALINER_GLASSFISH_DOMAIN="`cd "$CATALINER_APPSERVER_VARDIR/domains" && ls -1d *`"
			    _N="`echo $CATALINER_GLASSFISH_DOMAIN | wc -l | sed 's, ,,g'`"
			    if [ x"$_N" != x1 ]; then
				echo "ERROR: Can not determine CATALINER_GLASSFISH_DOMAIN automatically (got '$CATALINER_GLASSFISH_DOMAIN')!" >&2
				cleanExit $SMF_EXIT_ERR_CONFIG
			    else
				CATALINER_GLASSFISH_DOMAIN="`echo "$CATALINER_GLASSFISH_DOMAIN" | sed 's,/$,,'`"
			    fi
			fi
			_LOGDIR="$CATALINER_APPSERVER_VARDIR/domains/$CATALINER_GLASSFISH_DOMAIN/logs"
			[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$_LOGDIR/server.log"
			[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$_LOGDIR/server.log"
			[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
			[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$_LOGDIR/gfstart.out"
			[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
			[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$_LOGDIR"
			;;
		    *node*)
			if [ x"$CATALINER_GLASSFISH_NODEAGENT" = x ]; then
			    CATALINER_GLASSFISH_NODEAGENT="`cd "$CATALINER_APPSERVER_VARDIR/nodeagents" && ls -1d *`"
			    _N="`echo $CATALINER_GLASSFISH_NODEAGENT | wc -l | sed 's, ,,g'`"
			    if [ x"$_N" != x1 ]; then
				echo "ERROR: Can not determine CATALINER_GLASSFISH_NODEAGENT automatically (got '$CATALINER_GLASSFISH_NODEAGENT'!" >&2
				cleanExit $SMF_EXIT_ERR_CONFIG
			    else
				CATALINER_GLASSFISH_NODEAGENT="`echo "$CATALINER_GLASSFISH_NODEAGENT" | sed 's,/$,,'`"
			    fi
			fi
			_LOGDIR="$CATALINER_APPSERVER_VARDIR/nodeagents/$CATALINER_GLASSFISH_NODEAGENT/agent/logs"
			[ x"$CATALINER_APPSERVER_MONFILE" = x ] && CATALINER_APPSERVER_MONFILE="$_LOGDIR/server.log"
			[ x"$CATALINER_APPSERVER_LOGFILE" = x ] && CATALINER_APPSERVER_LOGFILE="$_LOGDIR/server.log"
			[ x"$CATALINER_APPSERVER_LOGFILE_RENAME" = x ] && CATALINER_APPSERVER_LOGFILE_RENAME="false"
			[ x"$CATALINER_APPSERVER_NOHUPFILE" = x ] && CATALINER_APPSERVER_NOHUPFILE="$_LOGDIR/gfstart.out"
			[ x"$CATALINER_APPSERVER_NOHUPFILE_WRITE" = x ] && CATALINER_APPSERVER_NOHUPFILE_WRITE="false"
			[ x"$CATALINER_WORKDIR" = x ] && CATALINER_WORKDIR="$_LOGDIR"
			;;
		    *inst*)
			echo "glassfish instance dir config needs more development" >&2
			cleanExit $SMF_EXIT_ERR_CONFIG
			;;
		    *cluster*)
			echo "glassfish cluster dir config needs more development" >&2
			cleanExit $SMF_EXIT_ERR_CONFIG
			;;
		esac
		;;
	*)
		[ x"$CATALINER_NONROOT" = x ] && CATALINER_NONROOT="false"
		;;
esac

# TODO: determine and utilize available bitness somehow?..
#CATALINER_SCRIPT_JVMBITS

### TODO: check server MEM sizing here
[ x"$CATALINA_OPTS_MEM" = xdefault ] && CATALINA_OPTS_MEM="$CATALINA_OPTS_MEM_DEFAULT"
if [ x"$CATALINA_OPTS" != x- ]; then
	[ x"$CATALINA_OPTS_MEM" != x- ] && CATALINA_OPTS="$CATALINA_OPTS $CATALINA_OPTS_MEM"
	[ x"CATALINER_SCRIPT_JVMBITS" != x- ] && CATALINA_OPTS="$CATALINA_OPTS $CATALINER_SCRIPT_JVMBITS"
	CATALINA_OPTS="$CATALINA_OPTS -server"
else
	if [ x"$JAVA_OPTS_START" != x- ]; then
		[ x"$CATALINER_SCRIPT_JVMBITS" != x- ] && JAVA_OPTS_START="$JAVA_OPTS_START $CATALINER_SCRIPT_JVMBITS"
		JAVA_OPTS_START="$JAVA_OPTS_START -server"
	fi
fi
[ x"$JAVA_OPTS_COMMON_ADDITIONAL" != x- -a x"$JAVA_OPTS_COMMON" != x- ] && \
	JAVA_OPTS_COMMON="$JAVA_OPTS_COMMON $JAVA_OPTS_COMMON_ADDITIONAL"
export CATALINA_OPTS
export JAVA_OPTS

validateConfigSanity INT
clearUndefinedVariables

######################################################################
###
### Configs have been set up from environment, hardcoded defaults, 
### generic and per-script-name config files, and service properties
###
### Now, check config validity in real life
###
######################################################################

### Check for non-root servers
### TODO: For SMF as non-root: see also RUNAS and set_run_as() above...
if [ x"$CATALINER_NONROOT" = x"true" ]; then
	if id | grep 'uid=0(' >/dev/null 2>&1; then
		echo "WARN: This script was executed by root but is configured for a simple user!"
		echo "    (CATALINER_NONROOT_USERNAME='$CATALINER_NONROOT_USERNAME', RUNAS='$RUNAS')"
		echo "    If required, export CATALINER_NONROOT=false before running"
		echo "    You might also want to chown work/data directories, etc."

		if [ x"$RUNAS" = x ]; then
			echo "ERROR: 'RUNAS' run-time variable has not been calculated. Configs may be wrong." >&2
			cleanExit $SMF_EXIT_ERR_CONFIG
		fi

### Suggested wrapper for init script ways (change uid in SMF by SMF is better):
### === /etc/init.d/alfresco_ctl 
###	#!/bin/sh
###	cd /opt/alfresco || exit 1
###	chown -R alfresco:other /opt/alfresco /export/home/alfresco 2>/dev/null
###	su - alfresco -c "cd /opt/alfresco; /opt/alfresco/alfresco.sh $@"
### ===
### NOTE that Alfresco may require many ports for its work, and would fail
### startup during "su" (or "run_as()") without proper privilege delegation.
### For some reason it often reports OutOfMemory errors despite same config.
### Works well as unprivileged under SMF with  privileges='basic,net_privaddr'

	fi
fi

if [ ! -d "$JAVA_HOME" -o ! -x "$JAVA_HOME/bin/java" ]; then
	echo "JAVA_HOME='$JAVA_HOME' is not correct" >&2
	case "$1" in
	    help|-h|--help|inspectlog|inspectLog_lastrun|inspectLog|revlines) ;;
	    *) cleanExit $SMF_EXIT_ERR_CONFIG ;;
	esac
fi
export JAVA_HOME

PATH="$JAVA_HOME/bin:$PATH"
export PATH

if [ ! -d "$CATALINER_APPSERVER_DIR" ]; then
	echo "CATALINER_APPSERVER_DIR='$CATALINER_APPSERVER_DIR' is not correct" >&2
	case "$1" in
	    help|-h|--help|inspectlog|inspectLog_lastrun|inspectLog|revlines) ;;
	    *) cleanExit $SMF_EXIT_ERR_CONFIG ;;
	esac
fi

[ x"$CATALINER_WORKDIR" = x -o ! -d "$CATALINER_WORKDIR" ] && CATALINER_WORKDIR="/var/tmp" || PATH="$CATALINER_WORKDIR:$PATH"
cd "$CATALINER_WORKDIR"
if [ $? != 0 ]; then
	echo "Can't change to working directory ($CATALINER_WORKDIR)"
	cleanExit $SMF_EXIT_ERR_CONFIG
fi

if [ x"$CATALINER_COREDUMPS_DISABLE" = xtrue ]; then
        echo "=== Disabling core file dumps: ulimit -c 0"
        ulimit -c 0
fi

[ x"$CATALINER_FILEDESC_LIMIT" = x-1 ] && CATALINER_FILEDESC_LIMIT=unlimited
if [ x"$CATALINER_FILEDESC_LIMIT" != x0 ]; then
	### In Linux see also: /etc/security/limits.conf, add lines like:
	###   * - nofile 122880
	###   root            soft     nofile         2048
	###   root            hard     nofile         2048
        ### Increase available file descriptors; don't use "unlimited"
	### (can make Java crazy)
        ### Solaris System maximum can be seen from a global zone with command:
        ### echo 'rlim_fd_max/D' | mdb -k | awk '{ print $2 }'
        echo "=== Setting FD limits: ulimit -n '$CATALINER_FILEDESC_LIMIT'"
        ulimit -n "$CATALINER_FILEDESC_LIMIT"

        if [ x"$_CATALINER_SCRIPT_OS" = xSunOS -a -f /usr/lib/extendedFILE.so.1 ]; then
                ### Help 32-bit processes with stdio limits, requires Sol10u4+
                ### See: http://developers.sun.com/solaris/articles/stdio_256.html
                echo "=== Setting LD_PRELOAD_32=/usr/lib/extendedFILE.so.1"
                LD_PRELOAD_32=/usr/lib/extendedFILE.so.1
                export LD_PRELOAD_32
        fi
fi                          

if [ x"$RUNAS" = x ]; then
	echo "=== INFO: Allowed number of file descriptors: `ulimit -n`"
else
	echo "=== INFO: Allowed number of file descriptors for unprivileged user ('$RUNAS'): `$RUNAS ulimit -n`"
fi

######################################################################
###	Finally, do what the caller requested...
######################################################################

trap "echo 'Killed by a signal, cleaning up...'; cleanExit $SMF_EXIT_ERR_FATAL" 1 2 3 15
trap "cleanExit" 0

echo ""

RET=$SMF_EXIT_OK
### Start or stop server, or run some requested self-tests, probes, locks, etc.
case "$1" in
	stop)
		method_stop
		RET=$?
		;;
	start)
		method_start
		RET=$?
		;;
	restart)
		method_restart
		RET=$?
		;;
	status|state)
		method_status
		RET=$? ;;
	probePostStart)
		probePostStart
		RET=$? ;;
	probePreStart)
		probePreStart
		RET=$? ;;
	probePostStop)
		probePostStop
		RET=$? ;;
	probePreStop)
		probePreStop
		RET=$? ;;
	probeldap|probeLDAP|probePreLDAP)
		probeldap
		RET=$? ;;
	probedbms|probeDBMS|probePreDBMS)
		probedbms
		RET=$? ;;
	probehttp|probeHTTP|probePreHTTP)
		probehttp
		RET=$? ;;
	probeamlogin|probeAMLogin|probePostAMLogin)
		probeamlogin
		RET=$? ;;
	lock)
		if [ ! -f "$LOCK.hard" ]; then
			echo "Setting administrative hard-lock '$LOCK.hard'..." >&2
			checkLockHard "$*"
			RET=$?
			if [ $RET != 0 ]; then
				echo "ERROR: Operation failed ($RET)" >&2
				RET=$RET
			fi
		else
			echo "Already HARD-locked by file '$LOCK.hard'!"
			echo "---"
			cat "$LOCK.hard"
			echo "---"
		fi
		;;
	unlock)
		if [ -f "$LOCK.hard" ]; then
			echo "Clearing administrative hard-lock '$LOCK.hard'..." >&2
			clearLockHard
			RET=$?
			if [ $RET != 0 ]; then
				echo "ERROR: Operation failed ($RET)" >&2
				RET=$RET
			fi
		else
			echo "Doesn't seem to be locked!"
		fi
		;;
	inspectLog_lastrun|inspectLog|inspectlog)
		shift 1
		inspectLog_lastrun $*
		RET=$?
		;;
	revlines) ### Internal method exposed for testing
		shift 1
		revlines $*
		RET=$?
		;;
	help|-h|--help)
		echo "$0: COS cataliner framework to manage Tomcat/JBOSS"
		echo '  $Id: cataliner.sh,v 1.116 2014/09/10 17:06:00 jim Exp $'
		echo "Controls Java appservers dedicated to running typical COS&HT applications."
		echo "Configurable by environment variables, SMF properties and/or config files."
		echo "Many comments in script should be quite informative about vars/code."
		echo "Usage:"
		echo "	start	sets JAVA_OPTS and other per-service env vars, starts JVM"
		echo "		and tries to monitor its startup until it logs success"
		echo "	stop	sets JAVA_OPTS and other per-service env vars, stop JVM"
		echo "		Tries to monitor its stop until the server log file is closed"
		echo "		Sets a timer to 'term' then 'kill' JVM if normal stop fails."
		echo "	restart	stop, then start"
		echo "	lock | unlock	Creates an administrative 'hard-lock' file to disable"
		echo "		stop, start and restart actions (i.e. via cron while admins are"
		echo "		doing maintenance). You can export CATALINER_SKIP_HARDLOCK=true"
		echo "		in your shell to do the administrative work."
		echo "	status | state	Current lock-file and JVM status"
		echo "	probePreStart | probePostStart | probePreStop | probePostStop"
		echo "		Run the possibly configured probes for external dependencies or"
		echo "		this server's availability/functionality tests"
		echo "	inspectlog [logfilename]	Inspect log file of this server (or the"
		echo "		named log file) and output start/stop times and error counts."
		echo "		Export INSPECT_DEPTH=N to review several appserver lifetimes."
		echo "	help | -h | --help	This help text."
		echo ""
		echo "Current invokation would run with settings:
CATALINER_SCRIPT_APP:		'$CATALINER_SCRIPT_APP'
_CATALINER_APPTYPE_CMDNAME:	'$_CATALINER_APPTYPE_CMDNAME'
\$0 \$@:  			$0 $@
_CATALINER_APPTYPE_SMFFMRI:	'$_CATALINER_APPTYPE_SMFFMRI'
CATALINER_APPSERVER_DIR:	'$CATALINER_APPSERVER_DIR'
CATALINER_APPSERVER_LOGFILE:	'$CATALINER_APPSERVER_LOGFILE'
CATALINER_APPSERVER_NOHUPFILE:	'$CATALINER_APPSERVER_NOHUPFILE'
SMF_FMRI:	'$SMF_FMRI'
RUNAS:		'$RUNAS'
JAVA_HOME:	'$JAVA_HOME'
JAVA_OPTS:	'$JAVA_OPTS'
CATALINA_OPTS:	'$CATALINA_OPTS'"
		echo ""

		getRunLevel DEBUG
		RET=$?
		;;
	*)	echo "FATAL ERROR: Unknown parameters: '$@'." >&2
		echo "Use '$0 --help' to get actual usage info" >&2
		RET=1
		;;
esac

### Clear the traps
trap "" 0 1 2 3 15

cleanExit $RET

