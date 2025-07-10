FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN echo "### Update system... ###"
# System-Update und Pakete installieren
RUN apt-get update && \
    apt-get install -y \
    xfce4 \
    xrdp \
    curl \
    unzip \
    sudo \
    dbus-x11 \
    x11-xserver-utils \
    python3-pip \
    libxrender1 \
    libxtst6 \
    libxi6 \
    ca-certificates \
    supervisor \
    libxext6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Java installieren (Temurin JRE 17)
RUN echo "### Install JDK newest version from temurin"    
RUN curl -L -o temurin.tar.gz https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.15%2B6/OpenJDK17U-jre_x64_linux_hotspot_17.0.15_6.tar.gz && \
    mkdir -p /opt/java && \
    tar -xzf temurin.tar.gz -C /opt/java --strip-components=1 && \
    rm temurin.tar.gz

ENV JAVA_HOME=/opt/java
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN echo "### Install uploadserver... ###"
#RUN pip install uploadserver
RUN pip install flask

# Benutzer anlegen
RUN useradd -m -s /bin/bash usuuser && \
    echo "usuuser:rdppass" | chpasswd && \
    adduser usuuser sudo

# RDP-Konfiguration
RUN echo xfce4-session > /home/usuuser/.xsession && \
    chown usuuser:usuuser /home/usuuser/.xsession

# xrdp aktivieren
RUN systemctl enable xrdp

# Arbeitsverzeichnisse
RUN echo "### Create folders... ###"
RUN mkdir -p /workspace/usu/rc-client && chown -R usuuser:usuuser /workspace
RUN mkdir -p /home/usuuser/.valuemation && chmod -R 777 /home/usuuser/.valuemation
RUN mkdir -p /workspace/usu/data/log && chmod -R 777 /workspace
RUN mkdir -p /workspace/usu/rc-client && chmod -R 777 /workspace/usu/rc-client

# Java-App & Ressourcen kopieren
RUN echo "### Copy Rich Client as tar.gz... ###"
COPY --chown=usuuser:usuuser rc-client.tar.gz.part-* /workspace/usu/
#COPY --chown=usuuser:usuuser resources/ /workspace/usu/resources/
COPY --chown=usuuser:usuuser resources/loginConfigurations.xml /home/usuuser/.valuemation/
COPY --chown=usuuser:usuuser resources/supervisord.conf /app/supervisord.conf
COPY --chown=usuuser:usuuser resources/.xsession /home/usuuser/.xsession
COPY --chown=usuuser:usuuser resources/uploadserver.py /workspace/usu/uploadserver.py

WORKDIR /workspace/usu

# App entpacken
RUN echo "### Extract Rich Client... ###"
RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
    tar -xzf rc-client.tar.gz && \
    rm rc-client.tar.gz* && \
    mv /workspace/usu/USM_*/* ./rc-client/

RUN echo "### Copy set_env with Java Path... ###"
COPY --chown=usuuser:usuuser resources/set_env_user.sh /workspace/usu/rc-client/

# Setze Startskript (optional)
COPY --chown=usuuser:usuuser resources/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 3389

RUN chown usuuser:usuuser -R /workspace

CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]

# Wechsel zu Benutzer
USER usuuser

# Arbeitsverzeichnis
WORKDIR /workspace/usu

# ############################################################
# # Basis-Image mit VNC, noVNC, Ubuntu 20.04 (focal)
# ###FROM dorowu/ubuntu-desktop-lxde-vnc:focal
# FROM theasp/novnc

# # Wechsle zu root für Paketinstallation
# USER root

# RUN echo "### Update system... ###"
# # Entferne ungültige Chrome-Repo-Quelle
# RUN rm -f /etc/apt/sources.list.d/google-chrome.list
# RUN echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list && \
#     echo "deb http://security.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
#     echo "deb http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list

# RUN apt-get update && \
#     DEBIAN_FRONTEND=noninteractive apt-get install -y \
#     unzip \
#     procps \
#     python3-pip \
#     curl \
#     ca-certificates \
#     libxrender1 \
#     libxtst6 \
#     libxi6 \
#     libxext6 \
#     libxrandr2 \
#     libfreetype6 \
#     libfontconfig1 \
#     libxfixes3 \
#     libxinerama1 \
#     libxcursor1 \
#     libglib2.0-0 \
#     libxcomposite1 \
#     libasound2 \
#     libxdamage1 \
#     libxss1 && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

#RUN echo "### Install JDK newest version from temurin"    
# Install latest Eclipse Temurin OpenJDK 17 (Adoptium)
#                              https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_linux_hotspot.tar.gz
# RUN curl -L -o temurin.tar.gz https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.15%2B6/OpenJDK17U-jre_x64_linux_hotspot_17.0.15_6.tar.gz && \
#     mkdir -p /opt/java && \
#     tar -xzf temurin.tar.gz -C /opt/java --strip-components=1 && \
#     rm temurin.tar.gz

# Set JAVA_HOME and PATH
# ENV JAVA_HOME=/opt/java
# ENV PATH="${JAVA_HOME}/bin:${PATH}"

# RUN echo "### Install uploadserver... ###"
# #RUN pip install uploadserver
# RUN pip install flask

# 26.06.2025 - ADD special user usuuser
# RUN useradd -m -s /bin/bash usuuser

#Debug Ausgabe der Datei
#RUN echo "=== DEBUG PRE: supervisord.conf ===" && ls -la /app/conf.d && cat /app/conf.d/*.conf

# RUN echo "### Create folders... ###"
# RUN mkdir -p /root/.valuemation && chmod -R 777 /root/.valuemation

# # 26.06.2025 - ADD special user
# RUN mkdir -p /home/usuuser/.valuemation && chmod -R 777 /home/usuuser/.valuemation
# RUN mkdir -p /workspace/usu/data/log && chmod -R 777 /workspace
# RUN mkdir -p /workspace/usu/rc-client && chmod -R 777 /workspace/usu/rc-client

# Entpacke das TAR-Archiv (enthält RC-Client.zip)
# RUN echo "### Copy Rich Client as tar.gz... ###"
# #copy Tar-files to image
# COPY rc-client.tar.gz.part-* /workspace/usu

# # 26.06.2025 - ADD special user
# COPY --chown=usuuser:usuuser resources/loginConfigurations.xml /home/usuuser/.valuemation/
# COPY --chown=usuuser:usuuser resources/supervisord.conf /app/supervisord.conf
# COPY --chown=usuuser:usuuser resources/uploadserver.py /workspace/usu/uploadserver.py

#USU Logo
#COPY resources/logo.js.png /usr/share/novnc/include/
#COPY resources/.bashrc /root/
#COPY resources/index.html /usr/share/novnc/

# Setze das Arbeitsverzeichnis
# WORKDIR /workspace/usu
# RUN echo "### Extract Rich Client... ###"
# # Entpacke das ZIP-Archiv im Container und füge die Teile zusammen
# RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
#     tar -xzf rc-client.tar.gz && \
#     rm rc-client.tar.gz*  # löscht Archiv und Part-Dateien
# RUN echo "### Move Rich Client... ###"
# RUN mv /workspace/usu/USM_*/* ./rc-client/

# RUN echo "### Copy set_env with Java Path... ###"
# COPY resources/set_env_user.sh /workspace/usu/rc-client/

# RUN chown usuuser:usuuser -R /workspace

# # Wechsel zu Benutzer
# USER usuuser

# # Neues PW für novnc setzen
# RUN mkdir -p /home/usuuser/.vnc && x11vnc -storepasswd 1234 /home/usuuser/.vnc/passwd

# # Arbeitsverzeichnis
# WORKDIR /workspace/usu

# Idee:
# wie kann ich in verschiedenen Dateien Platzhalter einbauen, die dann beim Deployment mit helm durch dann notwendige Werte im Image ersetzt werden?
# Beispiel: in einer XML-Datei muss ein Benutzer und ein Passwort gesetzt werden, das in einer secrets.yaml stehen kann?