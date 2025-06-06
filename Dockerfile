# Basis-Image mit VNC, noVNC, Ubuntu 20.04 (focal)
###FROM dorowu/ubuntu-desktop-lxde-vnc:focal
FROM theasp/novnc

# Wechsle zu root für Paketinstallation
###USER root

# Entferne ungültige Chrome-Repo-Quelle
RUN rm -f /etc/apt/sources.list.d/google-chrome.list

# Installiere Java 11 und unzip
###openjdk-11-jdk
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk unzip && \
    apt-get clean
RUN apt install openssh-server -y
RUN systemctl enable ssh

# Erstelle Zielverzeichnis
###RUN mkdir -p /opt/usu

RUN mkdir -p /root/.valuemation
RUN mkdir -p /workspace/usu/
RUN mkdir -p /local/

# Entpacke das TAR-Archiv (enthält RC-Client.zip)
#RUN tar -xf /opt/usu/rc-client.tar.001 -C /opt/usu/

#no TAR file will be used
#COPY rc-client.tar* /opt/usu
#RUN cat /opt/usu/rc-client.tar.* > /opt/usu/rc-client.tar && tar xf /opt/usu/rc-client.tar -C /opt/usu/
#RUN rm /opt/usu/*.tar*
#COPY rc-client.zip* /opt/usu

#copy Tar-files to image
COPY rc-client.tar.gz.part-* /workspace/usu
# Entpacke das ZIP-Archiv im Container
#RUN unzip /opt/usu/rc-client.zip* -d /opt/usu/rc-client && \
#    chmod +x /opt/usu/rc-client/admin.sh

# Setze das Arbeitsverzeichnis
WORKDIR /workspace/usu

# Füge die Teile zusammen
RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
    tar -xzf rc-client.tar.gz && \
    rm rc-client.tar.gz*  # löscht Archiv und Part-Dateien

COPY resources/loginConfigurations.xml /root/.valuemation/
COPY resources/set_env_user.sh /workspace/usmclient/

#USU Logo
#COPY resources/logo.js.png /usr/share/novnc/include/
COPY resources/.bashrc /root/
COPY resources/index.html /usr/share/novnc/

# Setze Arbeitsverzeichnis
WORKDIR /workspace/usu/rc-client

# Optional: zurück zu Standardbenutzer
USER 1000

# Starte deine App über das Startskript - passiert dann in der .bashrc
### CMD ["./admin.sh"]

# NoVNC/VNC starten + Terminal öffnen + deine App starten (falls gewünscht)
#CMD ["/startup.sh"]
