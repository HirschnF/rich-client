#!/bin/sh

#######################################################################################################################
# Please adjust these values that they fit your system
#######################################################################################################################
#ORC_JAVA_HOME=$JAVA_HOME
ORC_JAVA_HOME=/opt/java21
ORC_HOME=../../Application/orchestra

JVMMS=256M
JVMMX=1024M
JVMSS=4000K

#######################################################################################################################
# DO NOT CHANGE ANY OF THE VARIABLES BELOW THIS LINE!!
#######################################################################################################################
ORC_JAVA_EXEC=$ORC_JAVA_HOME/bin/java

ORC_UPDATE_CLASSPATH="$ORC_HOME/WEB-INF/libpatch/*:$ORC_HOME/WEB-INF/classes"

ORC_CLASSPATH="$ORC_HOME/WEB-INF/lib/*"
ORC_CLASSPATH="$ORC_CLASSPATH:$ORC_HOME/WEB-INF/classes"
ORC_CLASSPATH="$ORC_CLASSPATH:$ORC_HOME/lib_designer/*"
ORC_CLASSPATH="$ORC_CLASSPATH:$ORC_HOME/WEB-INF/libpatch/*"