#!/bin/sh

### This script is an early example alternative to providing `cataliner`
### settings from a wrapper script. This is no longer a recommended method.
### Code below may have been modified from version:
### $Id: alfresco.sh,v 1.6 2010/11/02 12:21:22 jim Exp $
### (C) Jim Klimov, dym 2009
### Sample wrapper for Cataliner to start and stop(!) and restart(!) alfresco
### with our needed params. Note: JAVA_OPTS defined here override the
### cataliner script definitions!

### Set the following to where Tomcat is installed
ALF_HOME=/opt/alfresco
cd "$ALF_HOME" 
if [ $? != 0 ]; then echo "Bad ALF_HOME='$ALF_HOME'" >&2 ; exit 1 ; fi

### NOTE: if you want to keep alfresco.log separately from ALF_HOME,
### this may be for you. Note that alfresco paths are relative to WORKDIR,
### i.e. for './bin/swf2pdf' calls, etc.:
# CATALINER_WORKDIR=/export/home/alfresco
# export CATALINER_WORKDIR
# cd "$CATALINER_WORKDIR"; if [ $? != 0 ]; then echo "Bad CATALINER_WORKDIR='$CATALINER_WORKDIR'" >&2 ; exit 1 ; fi

### NOTE: data is kept in   dir.root, may be /export/alfresco/alf_data
### It's set (default = "$ALF_HOME/alf_data") along with DBMS properties in:
#$ALF_HOME/tomcat/shared/classes/alfresco/extension/custom-repository.properties

CATALINER_SCRIPT_APP=alfresco-tomcat
CATALINER_NONROOT=no
JAVA_HOME=/opt/java
export CATALINER_NONROOT CATALINER_SCRIPT_APP JAVA_HOME ALF_HOME

PATH="$JAVA_HOME/bin:$PATH"
export PATH

### Should alfresco startup/shutdown also take care of OpenOffice daemon?
# CATALINER_ALF_OPENOFFICE=yes
# export CATALINER_ALF_OPENOFFICE

### Should alfresco startup/shutdown also take care of WCM "virtual server"?
# CATALINER_ALF_VIRTUAL=no
# export CATALINER_ALF_VIRTUAL

######## Form some JAVA_OPTS if script defaults don't fit.
### Note: non-empty JAVA_OPTS overrides everything in cataliner.sh script!
### ...
#JAVA_OPTS="..."
#export JAVA_OPTS
### If you decide to set all needed options in JAVA_OPTS, you may want to
### force empty CATALINA_OPTS (and avoid auto-value in cataliner.sh) like this:
#CATALINA_OPTS=-
#export CATALINA_OPTS

######## Propose custom memory settings via CATALINA_OPTS_MEM
#CATALINA_OPTS_MEM="-Xms512m -Xmx2048m -XX:MaxPermSize=256m"
#CATALINA_OPTS_MEM="default"

/etc/init.d/cataliner.sh "$@"

