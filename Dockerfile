# Based on Ubuntu 21.10
FROM ubuntu:21.10

# Maintainer
LABEL maintainer "Alexander Graf <alex@otherguy.io>"

# Required to prevent warnings
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true

# Change working directory
WORKDIR /opt/dropbox/Dropbox

# Not really required for --net=host
EXPOSE 17500

# Set language
ENV LANG   "C.UTF-8"
ENV LC_ALL "C.UTF-8"

# Install prerequisites
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
   software-properties-common gnupg2 curl \
   libglapi-mesa libxext-dev libxdamage-dev libxshmfence-dev libxxf86vm-dev \
   libxcb-glx0 libxcb-dri2-0 libxcb-dri3-0 libxcb-present-dev \
   ca-certificates gosu tzdata libc6 libxdamage1 libxcb-present0 \
   libxcb-sync1 libxshmfence1 libxxf86vm1 python3-gpg

# Create user and group
RUN mkdir -p /opt/dropbox /opt/dropbox/.dropbox /opt/dropbox/Dropbox \
 && useradd --home-dir /opt/dropbox --comment "Dropbox Daemon Account" --user-group --shell /usr/sbin/nologin dropbox \
 && chown -R dropbox:dropbox /opt/dropbox

# https://help.dropbox.com/installs-integrations/desktop/linux-repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FC918B335044912E \
 && add-apt-repository 'deb http://linux.dropbox.com/debian buster main' \
 && apt-get update \
 && apt-get -qqy install dropbox \
 && apt-get -qqy autoclean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Dropbox insists on downloading its binaries itself via 'dropbox start -i'
RUN echo "y" | gosu dropbox dropbox start -i

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /opt/dropbox/ and /tmp.
#
# https://bbs.archlinux.org/viewtopic.php?id=191001
RUN mkdir -p /opt/dropbox/bin/ /tmp \
 && mv /opt/dropbox/.dropbox-dist/* /opt/dropbox/bin/ \
 && rm -rf /opt/dropbox/.dropbox-dist \
 && install -dm0 /opt/dropbox/.dropbox-dist \
 && chmod u-w /opt/dropbox/.dropbox-dist \
 && chmod o-w /tmp \
 && chmod g-w /tmp

# Create volumes
VOLUME ["/opt/dropbox/.dropbox", "/opt/dropbox/Dropbox"]

# Build arguments
ARG VCS_REF=main
ARG VERSION=""
ARG BUILD_DATE=""

# http://label-schema.org/rc1/
LABEL org.label-schema.schema-version "1.0"
LABEL org.label-schema.name           "Dropbox"
LABEL org.label-schema.version        "${VERSION}"
LABEL org.label-schema.build-date     "${BUILD_DATE}"
LABEL org.label-schema.description    "Standalone Dropbox client"
LABEL org.label-schema.vcs-url        "https://github.com/otherguy/docker-dropbox"
LABEL org.label-schema.vcs-ref        "${VCS_REF}"

# Configurable sleep delay
ENV POLLING_INTERVAL=5
# Possibility to skip permission check
ENV SKIP_SET_PERMISSIONS=false

# Install init script and dropbox command line wrapper
COPY docker-entrypoint.sh /

# Set entrypoint and command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/dropbox/bin/dropboxd"]
