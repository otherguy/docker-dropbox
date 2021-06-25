#!/bin/bash

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

if [[ ! "${POLLING_INTERVAL}" =~ ^[0-9]+$ ]]; then
  echo "POLLING_INTERVAL not set to a valid number, defaulting to 5!"
  export POLLING_INTERVAL=5
fi

# Set dropbox account's UID/GID.
usermod -u ${DROPBOX_UID} -g ${DROPBOX_GID} --non-unique dropbox > /dev/null 2>&1

# Change ownership to dropbox account on all working folders.
if [[ $(echo "${SKIP_SET_PERMISSIONS:-false}" | tr '[:upper:]' '[:lower:]' | tr -d " ") == "true" ]]; then
  echo "Skipping permissions check, ensure the dropbox user owns all files!"
  chown ${DROPBOX_UID}:${DROPBOX_GID} /opt/dropbox
else
  chown -R ${DROPBOX_UID}:${DROPBOX_GID} /opt/dropbox
fi

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

# Start Dropbox
echo "Starting dropboxd ($(cat /opt/dropbox/bin/VERSION))..."
gosu dropbox "$@" & export DROPBOX_PID="$!"
trap "/bin/kill -SIGQUIT ${DROPBOX_PID}" INT

# Wait a few seconds for the Dropbox daemon to start
sleep 5

# Dropbox likes to restart itself. In that case, the container will exit!
while kill -0 ${DROPBOX_PID} 2> /dev/null; do
  [ -d "/proc/${DROPBOX_PID}" ] && [ -f "/opt/dropbox/.dropbox/info.json" ] && gosu dropbox dropbox status
  /usr/bin/find /tmp/ -maxdepth 1 -type d -mtime +1 ! -path /tmp/ -exec rm -rf {} \;
  /bin/sleep ${POLLING_INTERVAL}
done
