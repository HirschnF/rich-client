# Basis-Image mit VNC, noVNC, Ubuntu 20.04 (focal)
###FROM dorowu/ubuntu-desktop-lxde-vnc:focal
FROM theasp/novnc


# Wechsle zu root für Paketinstallation
USER root

RUN echo "### Update system... ###"
# Entferne ungültige Chrome-Repo-Quelle
RUN rm -f /etc/apt/sources.list.d/google-chrome.list
RUN echo "deb http://ftp.de.debian.org/debian bullseye main" > /etc/apt/sources.list

# Installiere Java 11 und unzip
###openjdk-11-jdk
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    apt-get install -y unzip && \
    apt-get clean


#RUN apt install openssh-server -y
#RUN systemctl enable ssh

# Erstelle Zielverzeichnis
###RUN mkdir -p /opt/usu

#Debug Ausgabe der Datei
#RUN echo "=== DEBUG PRE: supervisord.conf ===" && ls -la /app/conf.d && cat /app/conf.d/*.conf

RUN echo "### Create folders... ###"
RUN mkdir -p /root/.valuemation && chmod -R 777 /root/.valuemation
#RUN mkdir -p /workspace/usu && chmod -R 777 /workspace/usu
RUN mkdir -p /workspace/usu/data && chmod -R 777 /workspace/usu/data
#RUN mkdir -p /local/
RUN mkdir -p /workspace/usu/rc-client && chmod -R 777 /workspace/usu/rc-client
#RUN mkdir -p /workspace/usu/rc-client/data && chmod -R 777 /workspace/usu/rc-client/data
#RUN chmod -R 777 /workspace

# Entpacke das TAR-Archiv (enthält RC-Client.zip)
#RUN tar -xf /opt/usu/rc-client.tar.001 -C /opt/usu/

#no TAR file will be used
#COPY rc-client.tar* /opt/usu
#RUN cat /opt/usu/rc-client.tar.* > /opt/usu/rc-client.tar && tar xf /opt/usu/rc-client.tar -C /opt/usu/
#RUN rm /opt/usu/*.tar*
#COPY rc-client.zip* /opt/usu
RUN echo "### Copy Rich Client as tar.gz... ###"
#copy Tar-files to image
COPY rc-client.tar.gz.part-* /workspace/usu
# Entpacke das ZIP-Archiv im Container
#RUN unzip /opt/usu/rc-client.zip* -d /opt/usu/rc-client && \
#    chmod +x /opt/usu/rc-client/admin.sh

COPY resources/loginConfigurations.xml /root/.valuemation/
COPY resources/supervisord.conf /app/supervisord.conf

#USU Logo
#COPY resources/logo.js.png /usr/share/novnc/include/
#COPY resources/.bashrc /root/
COPY resources/index.html /usr/share/novnc/
#COPY resources/supervisord.conf /app/supervisord.conf
#COPY resources/supervisord.conf /app/conf.d/supervisord.conf

# Setze das Arbeitsverzeichnis
WORKDIR /workspace/usu
RUN echo "### Extract Rich Client... ###"
# Füge die Teile zusammen
RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
    tar -xzf rc-client.tar.gz && \
    rm rc-client.tar.gz*  # löscht Archiv und Part-Dateien
RUN echo "### Move Rich Client... ###"
RUN mv /workspace/usu/USM_*/* ./rc-client/

RUN echo "### Copy set_env with Java Path... ###"
COPY resources/set_env_user.sh /workspace/usu/rc-client/

# Setze Arbeitsverzeichnis

#WORKDIR /workspace/usu/data

# Optional: zurück zu Standardbenutzer
#USER 1000

#WORKDIR /workspace/usu/data

#Debug Ausgabe der Datei
#RUN echo "=== DEBUG POST: supervisord.conf ===" && cat /app/supervisord.conf

#RUN echo "Create Supervisord.log"
#RUN echo "" >> /workspace/usu/rc-client/data/supervisord.log

# Starte deine App über das Startskript - passiert dann in der .bashrc
### CMD ["./admin.sh"]

# NoVNC/VNC starten + Terminal öffnen + deine App starten (falls gewünscht)
#CMD ["/startup.sh"]

# Idee:
# wie kann ich in verschiedenen Dateien Platzhalter einbauen, die dann beim Deployment mit helm durch dann notwendige Werte im Image ersetzt werden?
# Beispiel: in einer XML-Datei muss ein Benutzer und ein Passwort gesetzt werden, das in einer secrets.yaml stehen kann?