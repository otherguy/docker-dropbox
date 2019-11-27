# Dropbox in Docker

[![Docker Pulls](https://img.shields.io/docker/pulls/otherguy/dropbox?style=flat-square)][dockerhub]
[![CircleCI](https://img.shields.io/circleci/build/github/otherguy/docker-dropbox/master?style=flat-square)][circleci]
[![MicroBadger Layers](https://img.shields.io/microbadger/layers/otherguy/docker-dropbox?style=flat-square)][microbadger]
[![GitHub stars](https://img.shields.io/github/stars/otherguy/docker-dropbox?color=violet&style=flat-square)][stargazers]
[![MIT License](https://img.shields.io/github/license/otherguy/docker-dropbox?color=orange&style=flat-square)][license]

[dockerhub]: https://hub.docker.com/r/otherguy/dropbox/
[license]: https://tldrlegal.com/license/mit-license
[circleci]: https://circleci.com/gh/otherguy/docker-dropbox
[microbadger]: https://microbadger.com/images/otherguy/dropbox
[stargazers]: https://github.com/otherguy/docker-dropbox/stargazers

Run Dropbox inside Docker. Fully working with local host folder mount or inter-container linking (via `--volumes-from`).

This repository provides the [otherguy/dropbox](https://registry.hub.docker.com/u/otherguy/dropbox/) image.

## Usage examples

### Quickstart

    $ docker run -d --restart=always --name=dropbox otherguy/dropbox

    $ docker run --detach --name=dropbox --restart=always -it -e DROPBOX_UID=$(id -u) -e DROPBOX_GID=$(id -g) -v "/root/.dropbox:/opt/dropbox/.dropbox" -v "/opt/dropbox:/opt/dropbox/Dropbox" otherguy/dropbox:latest

### Dropbox data mounted to local folder on the host

    $ docker run -d --restart=always --name=dropbox \
    -v /path/to/localfolder:/opt/dropbox/Dropbox \
    otherguy/dropbox

### Run dropbox with custom user/group id
This fixes file permission errrors that might occur when mounting the Dropbox file folder (`/opt/dropbox/Dropbox`) from the host or a Docker container volume. You need to set `DROPBOX_UID`/`DROPBOX_GID` to the user id and group id of whoever owns these files on the host or in the other container.

    docker run -d --restart=always --name=dropbox \
    -e DROPBOX_UID=110 \
    -e DROPBOX_GID=200 \
    otherguy/dropbox

### Enable LAN Sync

    docker run -d --restart=always --name=dropbox \
    --net="host" \
    otherguy/dropbox

## Linking to Dropbox account after first start

Check the logs of the container to get URL to authenticate with your Dropbox account.

    docker logs dropbox

Copy and paste the URL in a browser and login to your Dropbox account to associate.

    docker logs dropbox

You should see something like this:

> "This computer is now linked to Dropbox. Welcome xxxx"

## Manage exclusions and check sync status

    docker exec -t -i dropbox dropbox help

## ENV variables

**DROPBOX_UID**  
Default: `1000`  
Run Dropbox with a custom user id (matching the owner of the mounted files)

**DROPBOX_GID**  
Default: `1000`  
Run Dropbox with a custom group id (matching the group of the mounted files)

**$DROPBOX_SKIP_UPDATE**  
Default: `False`  
Set this to `True` to skip updating to the latest Dropbox version on container start

## Exposed volumes

//opt/dropbox/Dropbox`
Dropbox files

`/opt/dropbox/.dropbox`
Dropbox account configuration
