# Basis-Image mit VNC, noVNC, Ubuntu 20.04 (focal)
FROM dorowu/ubuntu-desktop-lxde-vnc:focal

# Wechsle zu root für Paketinstallation
USER root

# Installiere Java 11 ohne apt-get: Nutze Temurin (Adoptium) Installer
#RUN mkdir -p /opt/java && \
#    curl -fsSL https://github.com/adoptium/temurin11-binaries/releases/latest/download/OpenJDK11U-jdk_x64_linux_hotspot.tar.gz \
#    | tar -xz -C /opt/java && \
#    ln -s /opt/java/jdk-11*/bin/java /usr/bin/java && \
#    java -version

# Installiere Java 11 und unzip
RUN apt-get update && \
    apt-get install -y openjdk-11-jdk unzip && \
    apt-get clean

# Erstelle Zielverzeichnis
RUN mkdir -p /opt/myapp

# Entpacke das TAR-Archiv (enthält RC-Client.zip)
#RUN tar -xf /opt/myapp/rc-client.tar.001 -C /opt/myapp/
RUN cat /opt/myapp/rc-client.tar.* > /opt/myapp/rc-client.tar && tar xf /opt/myapp/rc-client.tar -C /opt/myapp/
RUN rm /opt/myapp/*.tar*

# Entpacke das ZIP-Archiv im Container
RUN unzip /opt/myapp/rc-client.zip -d /opt/myapp/rc-client && \
    chmod +x /opt/myapp/rc-client/admin.sh

# Setze Arbeitsverzeichnis
WORKDIR /opt/myapp/rc-client

# Optional: zurück zu Standardbenutzer
USER 1000

# Starte deine App über das Startskript
CMD ["./admin.sh"]

# NoVNC/VNC starten + Terminal öffnen + deine App starten (falls gewünscht)
#CMD ["/startup.sh"]
