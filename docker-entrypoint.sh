#!/bin/bash
# This script is a fork of https://github.com/excelsiord/docker-dropbox

# Set TZ if not provided with enviromental variable.
if [ -z "${TZ}" ]; then
  export TZ="$(cat /etc/timezone)"
else
  if [ ! -f "/usr/share/zoneinfo/${TZ}" ]; then
      echo "The timezone '${TZ}' is unavailable!"
      exit 1
  fi
  
  echo "${TZ}" > /etc/timezone
  ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime
fi

# Set UID/GID if not provided with enviromental variable(s).
if [ -z "${DROPBOX_UID}" ]; then
  export DROPBOX_UID=$(/usr/bin/id -u dropbox)
  echo "DROPBOX_UID not specified, defaulting to dropbox user id (${DROPBOX_UID})"
fi

if [ -z "${DROPBOX_GID}" ]; then
  export DROPBOX_GID=$(/usr/bin/id -g dropbox)
  echo "DROPBOX_GID not specified, defaulting to dropbox user group id (${DROPBOX_GID})"
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
    find /opt/dropbox/bin/ -type f -name "*.so" -exec chown ${DROPBOX_UID}:${DROPBOX_GID} {} \; -exec chmod a+rx {} \;
  	echo "Dropbox updated to v$Latest"
  else
    echo "Dropbox is up-to-date"
  fi
fi

# Empty line
echo ""

# Set umask
umask 002

# Print timezone
echo "Using $(cat /etc/timezone) timezone ($(date +%H:%M:%S) local time)"
dpkg-reconfigure --frontend noninteractive tzdata

echo "Starting dropboxd ($(cat /opt/dropbox/bin/VERSION))..."
exec gosu dropbox "$@" &
   pid="$!"
   trap "kill -SIGQUIT $pid" INT
   wait