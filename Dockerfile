# Based on Ubuntu 22.04
FROM ubuntu:22.04

# Maintainer
LABEL maintainer "Alexander Graf <alex@otherguy.io>"

# Required to prevent warnings
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true

# Change working directory
WORKDIR /opt/dropbox

# Not really required for --net=host
EXPOSE 17500

# Set language
ENV LANG   "C.UTF-8"
ENV LC_ALL "C.UTF-8"

# Install prerequisites
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
   software-properties-common gnupg2 curl wget \
   libglapi-mesa libxext-dev libxdamage-dev libxshmfence-dev libxxf86vm-dev \
   libxcb-glx0 libxcb-dri2-0 libxcb-dri3-0 libxcb-present-dev \
   ca-certificates gosu tzdata libc6 libxdamage1 libxcb-present0 \
   libxcb-sync1 libxshmfence1 libxxf86vm1 python3-gpg python3-pip

# Create user and group
RUN mkdir -p /opt/dropbox \
 && useradd --home-dir /opt/dropbox --comment "Dropbox Daemon Account" --user-group --shell /usr/sbin/nologin dropbox \
 && chown -R dropbox:dropbox /opt/dropbox

# Create volumes
VOLUME ["/opt/dropbox"]

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
# Possibility to enable Prometheus monitoring
ENV ENABLE_MONITORING=false

# Install init script and dropbox command line wrapper
COPY docker-entrypoint.sh /

# Install monitoring script
COPY monitoring.py /

# Set entrypoint and command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/dropbox/bin/dropboxd"]
