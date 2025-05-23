# Basis-Image mit VNC, noVNC, Ubuntu 20.04 (focal)
FROM dorowu/ubuntu-desktop-lxde-vnc:focal

# Wechsle zu root für Paketinstallation
USER root

# Entferne ungültige Chrome-Repo-Quelle
RUN rm -f /etc/apt/sources.list.d/google-chrome.list

# Installiere Java 11 und unzip
RUN apt-get update && \
    apt-get install -y openjdk-11-jdk unzip && \
    apt-get clean

# Erstelle Zielverzeichnis
RUN mkdir -p /opt/myapp

# Entpacke das TAR-Archiv (enthält RC-Client.zip)
#RUN tar -xf /opt/myapp/rc-client.tar.001 -C /opt/myapp/

#no TAR file will be used
#COPY rc-client.tar* /opt/myapp
#RUN cat /opt/myapp/rc-client.tar.* > /opt/myapp/rc-client.tar && tar xf /opt/myapp/rc-client.tar -C /opt/myapp/
#RUN rm /opt/myapp/*.tar*
#COPY rc-client.zip* /opt/myapp

#########################################################
#For creating the tar files correctly use this on your GIT Bash on windows
#$ tar -czf rc-client.tar.gz ./USM_5_5_HOTFIX01_B036_jetty
#$ split -b 90m rc-client.tar.gz rc-client.tar.gz.part-
#$ rm rc-client.tar.gz
#$ mv rc-client.tar.gz.part-* /c/transfer/rich-client
#########################################################

#copy Tar-files to image
COPY rc-client.tar.gz.part-* /opt/myapp
# Entpacke das ZIP-Archiv im Container
#RUN unzip /opt/myapp/rc-client.zip* -d /opt/myapp/rc-client && \
#    chmod +x /opt/myapp/rc-client/admin.sh

# Füge die Teile zusammen
RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
    tar -xzf rc-client.tar.gz && \
    rm rc-client.tar.gz*  # löscht Archiv und Part-Dateien

# Setze Arbeitsverzeichnis
WORKDIR /opt/myapp/rc-client

# Optional: zurück zu Standardbenutzer
USER 1000

# Starte deine App über das Startskript
CMD ["./admin.sh"]

# NoVNC/VNC starten + Terminal öffnen + deine App starten (falls gewünscht)
#CMD ["/startup.sh"]
