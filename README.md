# 🐳 Dropbox Docker Image

_This repository provides the [`otherguy/dropbox`][dockerhub] image_

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

Run Dropbox inside a Docker container. Complete with local host folder mount or inter-container
linking (via `--volumes-from`).

## 🚀 Usage

### Quickstart

This is the full command to start the Dropbox container. All volumes, environment variables and parameters
are explained in the sections below.

    $ docker run --detach -it --restart=always --name=dropbox \
      -e DROPBOX_UID=$(id -u) \
      -e DROPBOX_GID=$(id -g) \
      -e MAX_USER_WATCHES=10000 \
      -v "/path/to/local/settings:/opt/dropbox/.dropbox" \
      -v "/path/to/local/dropbox:/opt/dropbox/Dropbox" \
      --net="host" \
      otherguy/dropbox:latest

### Persisting Data

When mounting the Dropbox data folder to your local filesystem, you need to set the `DROPBOX_UID` and
`DROPBOX_GID` environment variables to the user id and group id of whoever owns these files on the host
or in the other container. Failing to do so causes file permission errrors.

The example below uses `id -u` and `id -g` to retrieve the current user's user id and group id, respectively.

    $ docker run --name=dropbox  \
      -e DROPBOX_UID=$(id -u) -e DROPBOX_GID=$(id -g) \
      -v "/path/to/local/settings:/opt/dropbox/.dropbox" \
      -v "/path/to/local/dropbox:/opt/dropbox/Dropbox" \
      [...]
      otherguy/dropbox:latest
      otherguy/dropbox:latest

### Enable LAN Sync

Using `--net="host"` allows Dropbox to utilize [local LAN sync]
(https://help.dropbox.com/installs-integrations/sync-uploads/lan-sync-overview).

    $ docker run --name=dropbox \
      --net="host" \
      [...]
      otherguy/dropbox:latest

### Linking Dropbox Account

To link Dropbox to your account, check the logs of the Docker container to retrieve the Dropbox
authentication URL:

    $ docker logs --follow dropbox

![Dropbox Account Linking](https://github.com/otherguy/docker-dropbox/raw/master/dropbox.gif)

Copy and paste the URL in a browser and login to your Dropbox account to associate the Docker container.
You should see something like this:

    This computer is now linked to Dropbox. Welcome [your name]"

### Manage Dropbox Settings

To manage Dropbox exclusions or get a sharing link, you need to execute the `dropbox` command inside the
Docker Dropbox container:

    $ docker exec -it dropbox gosu dropbox dropbox [dropbox command]

For example, to get an overview of the commands possible, use `help`:

    $ docker exec -it dropbox gosu dropbox dropbox help

## Configuration

### Environment Variables

- `DROPBOX_UID`
If set, runs Dropbox with a custom user id. This **must** match the user id of the owner of the mounted
files. Defaults to `1000`.

- `DROPBOX_GID`
If set, runs Dropbox with a custom user id. This **must** match the group id of the owner of the mounted
files. Defaults to `1000`.

- `DROPBOX_SKIP_UPDATE`
If set to `true`, skips updating the Dropbox app on container startup. _Note:_ This is not very reliable
because the Dropbox daemon will still try to update itself even if this is set to `true`.

- `MAX_USER_WATCHES`
If your Dropbox data contains a lot of small files and folders, the container might fail with an error like
`Unable to monitor entire Dropbox folder hierarchy.`. In this case, set this value to `100000`.

### Exposed Volumes

- `/opt/dropbox/Dropbox`
The actual Dropbox folder, containing all your synced files.

- `/opt/dropbox/.dropbox`
Account and other settings for Dropbox. If you don't mount this folder, your account needs to be linked
every time you restart the container.

## Note 📝

It appears that as of Dropbox version `81.3.183`, the [`dropbox-filesystem-fix` patch](https://github.com/dark/dropbox-filesystem-fix/)
is [unable to get around the filesystem detection](https://github.com/dark/dropbox-filesystem-fix/issues/13).


## 💅 Inspiration

Originally forked from [`janeczku/dropbox`](https://hub.docker.com/r/janeczku/dropbox/). Thank you
[@janeczku](https://github.com/janeczku) for your work!

## 🚧 Contributing

Bug reports and pull requests are welcome on GitHub at [`otherguy/docker-dropbox`](https://github.com/otherguy/docker-dropbox).
