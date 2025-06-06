# NoVNC - Rich Client im Web

## Docker Repository Test
https://hub.docker.com/repositories/frank1977

## Github Repository - Build and Push Docker Image
https://github.com/HirschnF/rich-client/actions/workflows/.github/workflows/docker-build.yml


## Rich Client Vorbereitung
<code>
#########################################################
#For creating the tar files correctly use this on your GIT Bash on windows
#$ tar -czf rc-client.tar.gz ./USM_5_5_HOTFIX01_B036_jetty
#$ split -b 90m rc-client.tar.gz rc-client.tar.gz.part-
#$ rm rc-client.tar.gz
#$ mv rc-client.tar.gz.part-* /c/transfer/rich-client
#########################################################
</code>

## Installation
<code>
$ helm upgrade --install jetty-user456 ./myapp-helm --namespace consult-usifhirsch-55 --set user=user456 --set image.repository=frank1977/jetty-rich-client --set image.tag=java17-novnc
</code>