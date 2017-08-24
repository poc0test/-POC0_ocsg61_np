# LICENSE CDDL 1.0 + GPL 2.0
# --------------------------
# This is a Dockerfile for OCSG 6.1 Install process 
#
# REQUIRED FILES TO BUILD THIS IMAGE
# ----------------------------------
# (1) ocsg_multitier_generic.jar
#     Download the Generic installer from https://edelivery.oracle.com/osdc/faces/Home.jspx
#
# (2) jdk-8u144-linux-x64.rpm
#     Download from http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
#
# HOW TO BUILD THIS IMAGE
# -----------------------
# Put all downloaded files in the same directory as this Dockerfile
# Run:
#      $ sudo docker build -t <name>/<name>:<tag / version> .
#
# Pull base image
# ---------------
#
FROM oraclelinux:6.6

# Maintainer
# ----------
LABEL authors="Gfi Infras DevOps Team"

# Environment variables required for this build
# -------------------------------------------------------------
ENV JAVA_RPM jdk-8u144-linux-x64.rpm
ENV OCSG_PKG ocsg_multitier_generic.jar
ENV JAVA_HOME /usr/java/default
ENV CONFIG_JVM_ARGS -Djava.security.egd=file:/dev/./urandom
ENV JAVA_OPTIONS -Djava.security.egd=file:/dev/./urandom
ENV PATH $PATH:/u01/oracle/ocsg/wlserver/common/bin:/u01/oracle/ocsg/user_projects/domains/ocsg-domain/bin:/u01/oracle

# WLS Configuration
# -------------------------------
ENV ADMIN_PASSWORD welcome1
ENV ADMIN_PORT 7001
ENV NM_PORT 5556
ENV MS_PORT 8001
ENV SIP_PORT 5060
ENV SIPS_PORT 5061
ENV USER_MEM_ARGS -Xms256m -Xmx512m -XX:MaxPermSize=2048m
ENV WL_HOME /u01/oracle/ocsg/wlserver

# Debug
RUN echo -e "welcome1\nwelcome1" | (passwd --stdin root)

# Setup required in relation to oracle user
# -----------------------------------------
RUN mkdir /u01 && \
    chmod a+xr /u01 && \
    useradd -b /u01 -m -s /bin/bash oracle

# Copy packages
COPY $OCSG_PKG /u01/
COPY $JAVA_RPM /u01/
COPY install.file /u01/
COPY installportal.file /u01/
COPY oraInst.loc /u01/
COPY container-scripts/* /u01/oracle/

# Install and configure Oracle JDK
# --------------------------------
RUN rpm -i /u01/$JAVA_RPM && \
    rm /u01/$JAVA_RPM

# Change the open file limits in /etc/security/limits.conf
RUN sed -i '/.*EOF/d' /etc/security/limits.conf && \
    echo "* soft nofile 16384" >> /etc/security/limits.conf && \
    echo "* hard nofile 16384" >> /etc/security/limits.conf && \
    echo "# EOF"  >> /etc/security/limits.conf

# Change the kernel parameters that need changing.
RUN echo "net.core.rmem_max=4192608" > /u01/oracle/.sysctl.conf && \
    echo "net.core.wmem_max=4192608" >> /u01/oracle/.sysctl.conf && \
    sysctl -e -p /u01/oracle/.sysctl.conf

# Adjust file permissions, go to /u01 as user 'oracle' to proceed with OCSG installation
RUN chown -R oracle:oracle /u01
WORKDIR /u01
USER oracle

# Installation of OCSG (Admin and Portal)
RUN mkdir /u01/oracle/.inventory
RUN java -jar $OCSG_PKG -ignoreSysPrereqs -novalidation -silent -responseFile /u01/install.file -invPtrLoc /u01/oraInst.loc -jreLoc $JAVA_HOME
RUN java -jar $OCSG_PKG -ignoreSysPrereqs -novalidation -silent -responseFile /u01/installportal.file -invPtrLoc /u01/oraInst.loc -jreLoc $JAVA_HOME

# Configuration of WLS Domain
WORKDIR /u01/oracle/ocsg
RUN /u01/oracle/ocsg/wlserver/common/bin/wlst.sh -skipWLSModuleScanning /u01/oracle/ocsg-domain.py && \
    mkdir -p /u01/oracle/ocsg/user_projects/domains/ocsg-domain/servers/AdminServer/security && \
    echo "username=weblogic" > /u01/oracle/ocsg/user_projects/domains/ocsg-domain/servers/AdminServer/security/boot.properties && \
    echo "password=$ADMIN_PASSWORD" >> /u01/oracle/ocsg/user_projects/domains/ocsg-domain/servers/AdminServer/security/boot.properties && \
    echo ". /u01/oracle/ocsg/user_projects/domains/ocsg-domain/bin/setDomainEnv.sh" >> /u01/oracle/.bashrc && \
    echo "export PATH=$PATH:/u01/oracle/ocsg/wlserver/common/bin:/u01/oracle/ocsg/user_projects/domains/ocsg-domain/bin" >> /u01/oracle/.bashrc && \
    sed -i 's#<source-path>/applications#<source-path>/u01/oracle/ocsg/ocsg/applications#g' /u01/oracle/ocsg/user_projects/domains/ocsg-domain/config/config.xml && \
    mkdir -p /u01/oracle/ocsg/user_projects/domains/ocsg-domain/autodeploy && \
    cp /u01/oracle/ocsg/ocsg/applications/apimgmtportal-* /u01/oracle/ocsg/user_projects/domains/ocsg-domain/autodeploy

# Delete files
RUN rm -f /u01/oracle/ocsg-domain.p y/u01/$OCSG_PKG /u01/oraInst.loc /u01/install.file /u01/installportal.file

# Expose Node Manager default port, and also default http/https ports for admin console
EXPOSE $NM_PORT $ADMIN_PORT $MS_PORT

# Some problems with IPv6
ENV JAVA_OPTIONS $JAVA_OPTIONS -Djava.net.preferIPv4Stack=true

# Define default command to start bash.
CMD ["/u01/oracle/startWebLogic.sh"]
