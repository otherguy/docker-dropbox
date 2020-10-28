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

Run Dropbox inside a Docker container. Supports local host folder mount or inter-container
linking via `--volumes-from`.

## 🚨 Warning for macOS Users

**For macOS users, mounting the Dropbox data folder is currently not possible!
See [`#6`](https://github.com/otherguy/docker-dropbox/issues/6) for details**

Back in 2018, Dropbox dropped support for several Linux filesystems and the Dropbox client [refused to
sync](https://www.dropboxforum.com/t5/Syncing-and-uploads/Dropbox-client-warns-me-that-it-ll-stop-syncing-in-Nov-why/td-p/290058)
when an unsupported filesystem was encountered.

In July 2019, the decision was [partially rolled back](https://www.dropboxforum.com/t5/Desktop-client-builds/Beta-Build-77-3-127/m-p/355527/highlight/true#M5361),
allowing syncing from ZFS (on 64-bit systems only), eCryptFS, XFS (on 64-bit systems only), and BTRFS
filesystems. Other filesystems dropped by the initial change are, however, still unsupported.

A [`dropbox-filesystem-fix` patch](https://github.com/dark/dropbox-filesystem-fix/) was developed by
[`@dark`](https://github.com/dark/) and was previously used in this Docker image to make it work with
Docker volume mounts, especially on macOS where the mounted volume uses the `FUSE` filesystem.

Unfortunately, as of `January 2020` (Dropbox version `87.4.138` and later, currently up to `95.4.441`), this
fix is [unable to get around the filesystem detection](https://github.com/dark/dropbox-filesystem-fix/issues/13)
in the newer Dropbox client versions. Using an older version of the Dropbox client is also not possible,
because the Dropbox API servers reject old client version and prevent them from connecting.

This breaks the possibility to mount a local folder via `-v "/path/to/local/dropbox:/opt/dropbox/Dropbox"`
on macOS systems.

## 🚀 Usage

### Quickstart

This is the full command to start the Dropbox container. All volumes, environment variables and parameters
are explained in the sections below.

    $ docker run --detach -it --restart=always --name=dropbox \
      --net="host" \
      -e "TZ=$(readlink /etc/localtime | sed 's#/var/db/timezone/zoneinfo/##')" \
      -e "DROPBOX_UID=$(id -u)" \
      -e "DROPBOX_GID=$(id -g)" \
      -v "/path/to/local/settings:/opt/dropbox/.dropbox" \
      -v "/path/to/local/dropbox:/opt/dropbox/Dropbox" \
      otherguy/dropbox:latest

### Persisting Data

When mounting the Dropbox data folder to your local filesystem, you need to set the `DROPBOX_UID` and
`DROPBOX_GID` environment variables to the user id and group id of whoever owns these files on the host
or in the other container. Failing to do so causes file permission errrors.

The example below uses `id -u` and `id -g` to retrieve the current user's user id and group id, respectively.

    $ docker run --name=dropbox \
      -e "DROPBOX_UID=$(id -u)" \
      -e "DROPBOX_GID=$(id -g)" \
      -v "/path/to/local/settings:/opt/dropbox/.dropbox" \
      -v "/path/to/local/dropbox:/opt/dropbox/Dropbox" \
      [...]
      otherguy/dropbox:latest

### Time Zones

It is also highly recommended to pass your local timezone settings into the container. This fixes the problem
of the host being on local time zone and container defaulting to `UTC` timezone. Dropbox is not checking time
zones when comparing file timestamps, leading to overwritten files and data loss.

You can pass your local timezone as an environment variable to the container: `-e "TZ=Australia/Brisbane"`

If you're on Linux 🐧, you can mount your `/etc/timezone` and `/etc/localtime` files into the container instead.

    $ docker run --name=dropbox \
      -v "/etc/timezone:/etc/timezone" \
      -v "/etc/localtime:/etc/localtime" \
      [...]
      otherguy/dropbox:latest

If you are on macOS, getting your current timezone and passing it into the container as an environment variable, 
is the simplest way:

    $ docker run --name=dropbox \
      -e "TZ=$(readlink /etc/localtime | sed 's#/var/db/timezone/zoneinfo/##')"
      [...]
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

Or to see the current sync status use `status`:

    $ docker exec -it dropbox gosu dropbox dropbox status

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

### Exposed Volumes

- `/opt/dropbox/Dropbox`
The actual Dropbox folder, containing all your synced files.

- `/opt/dropbox/.dropbox`
Account and other settings for Dropbox. If you don't mount this folder, your account needs to be linked
every time you restart the container.

## 💅 Inspiration

Originally forked from [`janeczku/dropbox`](https://hub.docker.com/r/janeczku/dropbox/). Thank you
[@janeczku](https://github.com/janeczku) for your work!

## 🚧 Contributing

Bug reports and pull requests are welcome on GitHub at [`otherguy/docker-dropbox`](https://github.com/otherguy/docker-dropbox).

## ♥️ Acknowledgements

- [Tony Pan](https://github.com/tcpan) for local timezone support ([`#3`](https://github.com/otherguy/docker-dropbox/pull/3))
