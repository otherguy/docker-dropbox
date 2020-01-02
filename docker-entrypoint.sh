#!/bin/bash
# This script is a fork of https://github.com/excelsiord/docker-dropbox

# Set UID/GID if not provided with enviromental variable(s).
if [ -z "${DROPBOX_UID}" ]; then
  export DROPBOX_UID=$(/usr/bin/id -u dropbox)
  echo "DROPBOX_UID not specified, defaulting to dropbox user id (${DROPBOX_UID})"
fi

if [ -z "${DROPBOX_GID}" ]; then
  export DROPBOX_GID=$(/usr/bin/id -g dropbox)
  echo "DROPBOX_GID not specified, defaulting to dropbox user group id (${DROPBOX_GID})"
fi

# Set Max Workers for fsnotify
if [ -n "${MAX_USER_WATCHES}" ]; then
  echo fs.inotify.max_user_watches=${MAX_USER_WATCHES} | tee -a /etc/sysctl.conf; sysctl -p
  echo "Setting fs.inotify.max_user_watches to ${MAX_USER_WATCHES}"
fi

# Look for existing group, if not found create dropbox with specified GID.
if [ -z "$(grep ":${DROPBOX_GID}:" /etc/group)" ]; then
  usermod -g users dropbox
  groupdel dropbox
  groupadd -g $DROPBOX_GID dropbox
fi

# Set dropbox account's UID/GID.
usermod -u ${DROPBOX_UID} -g ${DROPBOX_GID} --non-unique dropbox > /dev/null 2>&1

# Change ownership to dropbox account on all working folders.
chown -R ${DROPBOX_UID}:${DROPBOX_GID} /opt/dropbox

# Change permissions on Dropbox folder
chmod 755 /opt/dropbox/Dropbox

#  Dropbox did not shutdown properly? Remove files.
[ ! -e "/opt/dropbox/.dropbox/command_socket" ] || rm /opt/dropbox/.dropbox/command_socket
[ ! -e "/opt/dropbox/.dropbox/iface_socket" ]   || rm /opt/dropbox/.dropbox/iface_socket
[ ! -e "/opt/dropbox/.dropbox/unlink.db" ]      || rm /opt/dropbox/.dropbox/unlink.db
[ ! -e "/opt/dropbox/.dropbox/dropbox.pid" ]    || rm /opt/dropbox/.dropbox/dropbox.pid

# Update Dropbox to latest version unless DROPBOX_SKIP_UPDATE is set
if [[ -z "$DROPBOX_SKIP_UPDATE" ]]; then
  echo "Checking for latest Dropbox version..."
  sleep 1

  # Get download link for latest dropbox version
  DL=$(curl -I -s https://www.dropbox.com/download/\?plat\=lnx.x86_64 | grep ocation | awk -F'ocation: ' '{print $2}')

  # Strip CRLF
  DL=${DL//[$'\t\r\n ']}

  # Extract version string
  Latest=$(echo $DL | sed 's/.*x86_64-\([0-9]*\.[0-9]*\.[0-9]*\)\.tar\.gz/\1/')

  # Get current Version
  Current=$(cat /opt/dropbox/bin/VERSION)
  echo "Latest   :" $Latest
  echo "Installed:" $Current
  if [ ! -z "${Latest}" ] && [ ! -z "${Current}" ] && [ $Current != $Latest ]; then
  	echo "Downloading Dropbox $Latest..."
  	tmpdir=`mktemp -d`
  	curl -# -L $DL | tar xzf - -C $tmpdir
  	echo "Installing new version..."
  	rm -rf /opt/dropbox/bin/*
  	mv $tmpdir/.dropbox-dist/* /opt/dropbox/bin/
  	rm -rf $tmpdir
    find /opt/dropbox/bin -type f -name "*.so" -exec chmod a+rx {} \;
    find /opt/dropbox/bin -type f -name "*.so" -exec chown dropbox {} \;
  	echo "Dropbox updated to v$Latest"
  else
    echo "Dropbox is up-to-date"
  fi
fi

echo ""
umask 002

echo "Patching dropbox_start.py for updated dropboxd path"
sed -i "s:~/.dropbox-dist/dropboxd:/opt/dropbox/bin/dropboxd:g" /opt/dropbox-filesystem-fix/dropbox_start.py
sed -i "s:/usr/bin/python:$(which python3):g" /opt/dropbox-filesystem-fix/dropbox_start.py

echo ""

echo "Starting dropboxd ($(cat /opt/dropbox/bin/VERSION))..."
gosu dropbox /opt/dropbox-filesystem-fix/dropbox_start.py
export DROPBOX_PID=$(pidof dropbox)
trap "kill -SIGQUIT ${DROPBOX_PID}" INT

# Dropbox likes to restart itself. In that case, the container will exit!
while kill -0 ${DROPBOX_PID} 2> /dev/null; do
  gosu dropbox dropbox status
  sleep 1
done

