# 🐳 Dropbox Docker Image

[![Docker Pulls](https://img.shields.io/docker/pulls/otherguy/dropbox)][dockerhub]
[![Docker Stars](https://img.shields.io/docker/stars/otherguy/dropbox)][dockerhub]
[![GitHub issues](https://img.shields.io/github/issues/otherguy/docker-dropbox)][issues]
[![Travis](https://img.shields.io/travis/com/otherguy/docker-dropbox)][travis]
[![MicroBadger Layers](https://img.shields.io/microbadger/layers/otherguy/docker-dropbox)][microbadger]
[![GitHub stars](https://img.shields.io/github/stars/otherguy/docker-dropbox?color=violet)][stargazers]
[![MIT License](https://img.shields.io/github/license/otherguy/docker-dropbox?color=orange)][license]

[dockerhub]: https://hub.docker.com/r/otherguy/dropbox/
[license]: https://tldrlegal.com/license/mit-license
[travis]: https://travis-ci.com/otherguy/docker-dropbox
[microbadger]: https://microbadger.com/images/otherguy/dropbox
[stargazers]: https://github.com/otherguy/docker-dropbox/stargazers
[issues]: https://github.com/otherguy/docker-dropbox/issues

Run Dropbox inside a Docker container. Fully working with local host folder mount or inter-container linking
(via `--volumes-from`). This repository provides the [`otherguy/dropbox`][dockerhub] image.

## Usage 🚀

### Quickstart

This starts the Dropbox container with default settings:

    $ docker run --detach --restart=always --name=dropbox otherguy/dropbox

### Persistent Dropbox Folder

It is recommended that you run dropbox with a custom user/group id when mounting the Dropbox file folder
to the local filesystem. This fixes file permission errrors that might occur when mounting from the host
or another Docker container volume.

You need to set the `DROPBOX_UID` and `DROPBOX_GID` environment variables to the user id and group id of w
hoever owns these files on the host or in the other container. The example below uses `id -u` and `id -g`
to retrieve the current user's user id and group id, respectively.

    $ docker run --detach --name=dropbox --restart=always \
      -e DROPBOX_UID=$(id -u) -e DROPBOX_GID=$(id -g) \
      -v "/path/to/local/settings:/opt/dropbox/.dropbox" \
      -v "/path/to/local/dropbox:/opt/dropbox/Dropbox" \
      otherguy/dropbox:latest

### Enable LAN Sync

Using `--net="host"` allows Dropbox to utilize
[local LAN sync](https://help.dropbox.com/installs-integrations/sync-uploads/lan-sync-overview).

    $ docker run --detach --name=dropbox --restart=always \
      --net="host" \
      otherguy/dropbox

### Linking Dropbox Account

To link Dropbox to your account, check the logs of the Docker container to retrieve the Dropbox authentication
URL:

    $ docker logs --follow dropbox

![Dropbox Account Linking](https://github.com/otherguy/docker-dropbox/raw/master/dropbox.gif)

Copy and paste the URL in a browser and login to your Dropbox account to associate the Docker container. You
should see something like this:

    This computer is now linked to Dropbox. Welcome [your name]"

### Manage Dropbox Settings

To manage dropbox exclusions or get a sharing link, you need to execute the `dropbox` command inside the
Docker dropbox container:

    $ docker exec -it dropbox gosu dropbox dropbox [dropbox command]

For example, to get an overview of the commands possible, use `help`:

    $ docker exec -it dropbox gosu dropbox dropbox help

## Configuration

### Environment Variables

- `DROPBOX_UID`
If set, runs Dropbox with a custom user id. This must matching the user id of the owner of the mounted
files. Defaults to `1000`.

- `DROPBOX_GID`
If set, runs Dropbox with a custom user id. This must matching the group id of the owner of the mounted
files. Defaults to `1000`.

### Exposed Volumes

- `/opt/dropbox/Dropbox`
The actual Dropbox folder, containing all your synced files.

- `/opt/dropbox/.dropbox`
Account and other settings for Dropbox. If you don't mount this folder, your account needs to be linked
every time you restart the container.

## Inspiration 💅

Originally forked from [`janeczku/dropbox`](https://hub.docker.com/r/janeczku/dropbox/). Thank you
[@janeczku](https://github.com/janeczku) for your work!

## Contributing 🚧

Bug reports and pull requests are welcome on GitHub at [`otherguy/docker-dropbox`](https://github.com/otherguy/docker-dropbox).
