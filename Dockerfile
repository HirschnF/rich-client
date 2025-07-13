# Stage 1: guacd aus dem offiziellen Image extrahieren
#FROM guacamole/guacd:1.5.4 as guacd

# Stage 2: Hauptcontainer
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/opt/java
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Systempakete installieren
RUN echo "### Update system... ###"
RUN apt-get update && apt-get install -y \
    sudo curl unzip gnupg2 software-properties-common \
    xrdp xfce4 dbus-x11 x11-xserver-utils \
    net-tools supervisor python3-pip \
    tomcat9 tomcat9-common\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Java 17 installieren (Temurin)
RUN echo "### Install JDK newest version from temurin"    
RUN curl -L -o temurin.tar.gz https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.15%2B6/OpenJDK17U-jre_x64_linux_hotspot_17.0.15_6.tar.gz && \
    mkdir -p /opt/java && \
    tar -xzf temurin.tar.gz -C /opt/java --strip-components=1 && \
    rm temurin.tar.gz

# Benutzer anlegen
RUN useradd -m -s /bin/bash usuuser && \
    echo "usuuser:rdppass" | chpasswd && \
    adduser usuuser sudo

# .xsession vorbereiten (wird später über ConfigMap überschrieben)
RUN echo -e '#!/bin/bash\n/workspace/usu/rc-client/admin.sh &\nexec startxfce4' > /home/usuuser/.xsession && \
    chmod +x /home/usuuser/.xsession && \
    chown usuuser:usuuser /home/usuuser/.xsession

# Arbeitsverzeichnisse
RUN echo "### Create folders... ###"
RUN mkdir -p /workspace/usu/rc-client /workspace/usu/data/log /home/usuuser/.valuemation && \
    chmod -R 777 /workspace && \
    chown -R usuuser:usuuser /workspace /home/usuuser/.valuemation

# guacd aus Stage 1 kopieren
# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libcairo2-dev libjpeg-dev libpng-dev libtool-bin \
    uuid-dev libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev \
    freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
    libpulse-dev libssl-dev libvorbis-dev libwebp-dev

# Build guacd
RUN curl -L -o /tmp/guacamole-server.tar.gz https://downloads.apache.org/guacamole/1.5.4/source/guacamole-server-1.5.4.tar.gz && \
    tar -xzf /tmp/guacamole-server.tar.gz -C /tmp && \
    cd /tmp/guacamole-server-1.5.4 && \
    LDFLAGS="-lrt" ./configure --with-init-dir=/etc/init.d && \
    make && \
    make install && \
    ldconfig && \
    rm -rf /tmp/guacamole-server*

# Optional: Clean up
RUN apt-get purge -y build-essential libtool-bin && \
    apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log && \
    touch /var/log/xrdp.log /var/log/xrdp-sesman.log && \
    chown usuuser: /var/log/xrdp*.log

#COPY --from=guacd /opt/guacamole /opt/guacamole
#/usr/local/sbin/guacd /usr/local/sbin/guacd
#COPY --from=guacd /usr/local/lib /usr/local/lib
#COPY --from=guacd /etc/guacamole /etc/guacamole

# Guacamole WebApp in Tomcat deployen
RUN echo "### Guacamole WAR file... ###"
RUN curl -L -o /var/lib/tomcat9/webapps/guacamole.war https://downloads.apache.org/guacamole/1.5.4/binary/guacamole-1.5.4.war
RUN rm -rf /var/lib/tomcat9/webapps/ROOT && \
    mkdir -p /var/lib/tomcat9/webapps/guacamole && \
    unzip -o /var/lib/tomcat9/webapps/guacamole.war -d /var/lib/tomcat9/webapps/guacamole

RUN mkdir -p /var/lib/tomcat9/base/conf/Catalina/localhost
RUN mkdir -p /var/lib/tomcat9/base/work/Catalina/localhost
#RUN chown tomcat:adm /var/lib/tomcat9/base

# Flask Uploadserver installieren
RUN echo "### Install uploadserver... ###"
RUN pip3 install flask

# Ressourcen kopieren (werden teilweise durch ConfigMaps überschrieben)
COPY rc-client.tar.gz.part-* /workspace/usu/
COPY resources/loginConfigurations.xml /home/usuuser/.valuemation/
COPY resources/supervisord.conf /etc/supervisor/supervisord.conf
COPY resources/uploadserver.py /workspace/usu/uploadserver.py
COPY resources/set_env_user.sh /workspace/usu/rc-client/

RUN mkdir -p /usr/share/tomcat9/conf
COPY --chown=tomcat:adm resources/tomcat/web.xml /usr/share/tomcat9/conf/web.xml
COPY --chown=tomcat:adm resources/tomcat/context.xml /usr/share/tomcat9/conf/context.xml
COPY --chown=tomcat:adm resources/tomcat/tomcat-users.xml /usr/share/tomcat9/conf/tomcat-users.xml
COPY --chown=tomcat:adm resources/tomcat/logging.properties /usr/share/tomcat9/conf/logging.properties
COPY --chown=tomcat:adm resources/tomcat/server.xml /usr/share/tomcat9/conf/server.xml

# Java-App entpacken
RUN echo "### Copy and Extract Rich Client as tar.gz... ###"
RUN cat /workspace/usu/rc-client.tar.gz.part-* > /workspace/usu/rc-client.tar.gz && \
    tar -xzf /workspace/usu/rc-client.tar.gz -C /workspace/usu && \
    mv /workspace/usu/USM_*/* /workspace/usu/rc-client && \
    rm -rf /workspace/usu/rc-client.tar.gz*

RUN mkdir -p /etc/guacamole   
RUN echo "auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider" >/etc/guacamole/guacamole.properties
RUN echo "basic-user-mapping: /etc/guacamole/user-mapping.xml" >>/etc/guacamole/guacamole.properties
RUN chmod 660 /etc/guacamole/guacamole.properties
RUN chown tomcat:adm /etc/guacamole/guacamole.properties

RUN ln -s /var/log/tomcat9/ /usr/share/tomcat9/logs
RUN touch /var/log/tomcat9/catalina.out
RUN chmod 664 /var/log/tomcat9/catalina.out
RUN ln -s /var/lib/tomcat9/webapps/ /usr/share/tomcat9/webapps
RUN chown tomcat:adm -R /var/lib/tomcat9
RUN chown tomcat:adm -R /usr/share/tomcat9

WORKDIR /workspace/usu
# Ports freigeben
EXPOSE 3389 8080 4822 8000 8087

RUN chown usuuser:usuuser -R /workspace
RUN usermod -aG adm usuuser

# Wechsel zu Benutzer
USER usuuser

# Start über supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
