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
    tomcat9 tomcat9-common tigervnc-standalone-server locales \ 
    chromium openbox \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Konfigurieren
RUN dpkg-reconfigure locales

# Java 17 installieren (Temurin)
RUN echo "### Install JDK newest version from temurin"    
RUN curl -L -o temurin.tar.gz https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.15%2B6/OpenJDK17U-jre_x64_linux_hotspot_17.0.15_6.tar.gz && \
    mkdir -p /opt/java && \
    tar -xzf temurin.tar.gz -C /opt/java --strip-components=1 && \
    rm temurin.tar.gz

# .xsession vorbereiten (wird später über ConfigMap überschrieben)
RUN echo "### Create folders... ###"
RUN mkdir -p /home/tomcat && mkdir -p /run/xrdp/sockdir && chown -R xrdp:xrdp /run/xrdp

COPY --chown=tomcat:adm resources/.xsession /home/tomcat    
# Arbeitsverzeichnisse
RUN mkdir -p /workspace/usu/rc-client /workspace/usu/data/log /home/tomcat/.valuemation && \
    chmod -R 777 /workspace && \
    chmod +x /home/tomcat/.xsession && \
    chown -R tomcat:tomcat /workspace /home/tomcat/.valuemation

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
    chown tomcat: /var/log/xrdp*.log
RUN { echo "auth required pam_debug.so"; cat /etc/pam.d/xrdp-sesman; } > temp && mv temp /etc/pam.d/xrdp-sesman

RUN xrdp-keygen xrdp /etc/xrdpkey 2048 && \
    chown -R tomcat: /etc/xrdp

RUN echo "LANG=de_DE.UTF-8\nLANGUAGE=de_DE:de\nLC_ALL=de_DE.UTF-8" > /etc/default/locale && \
    sed -i '/^# *de_DE.UTF-8 UTF-8/s/^# *//' /etc/locale.gen && \
    locale-gen de_DE.UTF-8 
#    && \
#    dpkg-reconfigure locales

# Guacamole WebApp in Tomcat deployen
RUN echo "### Guacamole WAR file... ###"
RUN curl -L -o /var/lib/tomcat9/webapps/guacamole.war https://downloads.apache.org/guacamole/1.5.4/binary/guacamole-1.5.4.war
RUN rm -rf /var/lib/tomcat9/webapps/ROOT && \
    mkdir -p /var/lib/tomcat9/webapps/guacamole && \
    unzip -o /var/lib/tomcat9/webapps/guacamole.war -d /var/lib/tomcat9/webapps/guacamole

# Flask Uploadserver installieren
RUN echo "### Install uploadserver... ###"
RUN pip3 install flask

# Ressourcen kopieren (werden teilweise durch ConfigMaps überschrieben)
COPY rc-client.tar.gz.part-* /workspace/usu/
COPY resources/loginConfigurations.xml /home/tomcat/.valuemation/
COPY resources/supervisord.conf /etc/supervisor/supervisord.conf
COPY resources/uploadserver.py /workspace/usu/uploadserver.py
#COPY resources/set_env_user.sh /workspace/usu/rc-client/set_env_user.sh

RUN mkdir -p /usr/share/tomcat9/conf && \
    mkdir -p /etc/guacamole   
COPY --chown=tomcat:adm resources/tomcat/web.xml /usr/share/tomcat9/conf/web.xml
COPY --chown=tomcat:adm resources/tomcat/context.xml /usr/share/tomcat9/conf/context.xml
COPY --chown=tomcat:adm resources/tomcat/tomcat-users.xml /usr/share/tomcat9/conf/tomcat-users.xml
COPY --chown=tomcat:adm resources/tomcat/logging.properties /usr/share/tomcat9/conf/logging.properties
COPY --chown=tomcat:adm resources/tomcat/server.xml /usr/share/tomcat9/conf/server.xml
COPY --chown=tomcat:adm resources/xrdp/sesman.ini /etc/xrdp/sesman.ini
COPY --chown=tomcat:adm resources/xrdp/xrdp.ini /etc/xrdp/xrdp.ini
COPY --chown=tomcat:adm resources/guacamole.properties /etc/guacamole/guacamole.properties
RUN chmod 660 /etc/guacamole/guacamole.properties

# Java-App entpacken
RUN echo "### Copy and Extract Rich Client as tar.gz... ###"
RUN cat /workspace/usu/rc-client.tar.gz.part-* > /workspace/usu/rc-client.tar.gz && \
    tar -xzf /workspace/usu/rc-client.tar.gz -C /workspace/usu && \
    mv /workspace/usu/USM_*/* /workspace/usu/rc-client && \
    rm -rf /workspace/usu/rc-client.tar.gz*

RUN ln -s /var/log/tomcat9/ /usr/share/tomcat9/logs
RUN touch /var/log/tomcat9/catalina.out
RUN chmod 664 /var/log/tomcat9/catalina.out
RUN ln -s /var/lib/tomcat9/webapps/ /usr/share/tomcat9/webapps
RUN chown tomcat:adm -R /var/lib/tomcat9
RUN chown tomcat:adm -R /usr/share/tomcat9

# Postman herunterladen und installieren
RUN curl -L https://dl.pstmn.io/download/latest/linux64 -o /tmp/postman.tar.gz && \
    mkdir -p /opt/Postman && \
    tar -xzf /tmp/postman.tar.gz -C /opt/Postman && \
    ln -s /opt/Postman/Postman /usr/local/bin/postman && \
    rm /tmp/postman.tar.gz

WORKDIR /workspace/usu
# Ports freigeben
EXPOSE 3389 8080 4822 8000 8087

RUN chown tomcat:tomcat -R /workspace
RUN usermod -aG adm tomcat && \
    usermod -aG shadow tomcat

# Wechsel zu Benutzer
USER tomcat

# Start über supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
