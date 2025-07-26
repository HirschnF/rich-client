# NoVNC - Rich Client im Web

## Docker Repository Test
https://hub.docker.com/repositories/frank1977

## Github Repository - Build and Push Docker Image
https://github.com/HirschnF/rich-client/actions/workflows/.github/workflows/docker-build.yml


## Rich Client Vorbereitung
```bash
#########################################################
#For creating the tar files correctly use this on your GIT Bash on windows
#$ tar -czf rc-client.tar.gz ./USM_5_5_HOTFIX01_B036_jetty
#$ split -b 90m rc-client.tar.gz rc-client.tar.gz.part-
#$ rm rc-client.tar.gz
#$ mv rc-client.tar.gz.part-* /c/transfer/rich-client
#########################################################
```

## Installation

    - Prepare your values.yaml from the "Rich Client"
    - set correct Namespace - replace it in the whole file (up to 7x)
    - set correct Database Password 


```bash
# Get the password from your USC package
$ cat secrets.yaml |grep "usmMariadbRootPassword"

$ helm upgrade --install jetty ./jetty-helm --namespace consult-ext-usesbenz-202516 --set user=usesbenz --set pw=1234567
# Create a secure password before with 12 Characters and share it with upass
```

## Uninstallation
```bash
$ helm uninstall jetty -n consult-summit-2025
```

## Deliver environment USupport Ticket
- From USC-Package installation path
```bash
$ cat ingress-urls.txt |grep "index"
#https://index.consult-ext-usesbenz-202516.k8s-dev004.aspera.usu.grp/

# Rich Client URL:
#https://rc.[URL]/transfer/
```


# Optimierung und Anpassungen 
## Dockerfile 
```bash
# Entfernte Pakete aus Zeile 9-13
# pamtester

#.xsession wird von Ressource schon kopiert und kann in Deployment und configmap entfernt werden 
# Deployment.yaml - Zeile 68
echo "#!/bin/bash\ncd /workspace/usu/rc-client\nexec xterm -e ./admin.sh " >/home/$RDP_USERNAME/.xsession && \
# Schleife hat funktioniert
#echo "#!/bin/bash\nopenbox &\nsetxkbmap de &\nxterm -u8 -e bash -c 'cd /workspace/usu/rc-client; while true; do ./admin.sh >/tmp/xterm-admin.log 2>&1; echo "Restart in 2 seconds..."; sleep 2; done' &" >/home/$RDP_USERNAME/.xsession && \
#\n/usr/local/bin/postman/Postman >/tmp/postman.log 2>&1 &\nwait " >/home/$RDP_USERNAME/.xsession && \

# Diverse Anpassungen bereits im Basis Image
mkdir -p /run/xrdp/sockdir && \
chown xrdp:xrdp /run/xrdp /run/xrdp/sockdir && \              
echo "LANG=de_DE.UTF-8\nLANGUAGE=de_DE:de\nLC_ALL=de_DE.UTF-8" > /etc/default/locale && \
{ echo "auth required pam_debug.so"; cat /etc/pam.d/xrdp-sesman; } > temp && mv temp /etc/pam.d/xrdp-sesman && \
sed -i '/^# *de_DE.UTF-8 UTF-8/s/^# *//' /etc/locale.gen && \
locale-gen && \
usermod -aG shadow tomcat && \

# Zeile 112
# RUN mkdir -p /etc/guacamole   
# RUN echo "auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider" >/etc/guacamole/guacamole.properties
# RUN echo "basic-user-mapping: /etc/guacamole/user-mapping.xml" >>/etc/guacamole/guacamole.properties

#RUN chown tomcat:adm /etc/guacamole/guacamole.properties

```