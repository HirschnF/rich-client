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
RUN mkdir -p /workspace/usu/data
RUN mkdir -p /local/
RUN mkdir -p /workspace/usu/rc-client

RUN chmod -R 777 /workspace
RUN chmod -R 777 /root/.valuemation

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

COPY resources/loginConfigurations.xml /root/.valuemation/
COPY resources/set_env_user.sh /workspace/usmclient/

#USU Logo
#COPY resources/logo.js.png /usr/share/novnc/include/
COPY resources/.bashrc /root/
COPY resources/index.html /usr/share/novnc/

# Setze das Arbeitsverzeichnis
WORKDIR /workspace/usu

# Füge die Teile zusammen
RUN cat rc-client.tar.gz.part-* > rc-client.tar.gz && \
    tar -xzf rc-client.tar.gz && \
    rm rc-client.tar.gz*  # löscht Archiv und Part-Dateien

# Setze Arbeitsverzeichnis

WORKDIR /workspace/usu/rc-client/data

# Optional: zurück zu Standardbenutzer
USER 1000

# Starte deine App über das Startskript - passiert dann in der .bashrc
### CMD ["./admin.sh"]

# NoVNC/VNC starten + Terminal öffnen + deine App starten (falls gewünscht)
#CMD ["/startup.sh"]

# Idee:
# wie kann ich in verschiedenen Dateien Platzhalter einbauen, die dann beim Deployment mit helm durch dann notwendige Werte im Image ersetzt werden?
# Beispiel: in einer XML-Datei muss ein Benutzer und ein Passwort gesetzt werden, das in einer secrets.yaml stehen kann?