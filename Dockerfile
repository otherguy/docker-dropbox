FROM debian:buster

# Maintainer
LABEL maintainer "Alexander Graf <alex@otherguy.io>"

# Build arguments
ARG VCS_REF=master
ARG BUILD_DATE=""

# http://label-schema.org/rc1/
LABEL org.label-schema.schema-version "1.0"
LABEL org.label-schema.name           "Dropbox"
LABEL org.label-schema.build-date     "${BUILD_DATE}"
LABEL org.label-schema.description    "Standalone Dropbox client on Linux"
LABEL org.label-schema.vcs-url        "https://github.com/otherguy/docker-dropbox"
LABEL org.label-schema.vcs-ref        "${VCS_REF}"

# Required to prevent warnings
ENV DEBIAN_FRONTEND noninteractive

# Install prerequisites
RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg2 software-properties-common gosu locales locales-all

# Create user and group
RUN mkdir -p /opt/dropbox /opt/dropbox/.dropbox /opt/dropbox/Dropbox \
 && useradd --home-dir /opt/dropbox --comment "Dropbox Daemon Account" --user-group --shell /usr/sbin/nologin dropbox \
 && chown -R dropbox:dropbox /opt/dropbox

# Set language
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Generate locales
RUN sed --in-place '/en_US.UTF-8/s/^# //' /etc/locale.gen \
 && locale-gen

# Change working directory
WORKDIR /opt/dropbox/Dropbox

# Not really required for --net=host
EXPOSE 17500

# https://help.dropbox.com/installs-integrations/desktop/linux-repository
RUN add-apt-repository 'deb http://linux.dropbox.com/debian buster main' \
 && apt-key adv --keyserver keyserver.ubuntu.com  --recv-keys 1C61A2656FB57B7E4DE0F4C1FC918B335044912E \
 && apt-get update \
 && apt-get install -y --no-install-recommends libatomic1 python3-gpg dropbox \
 && rm -rf /var/lib/apt/lists/*

# Dropbox insists on downloading its binaries itself via 'dropbox start -i'
RUN echo "y" | gosu dropbox dropbox start -i

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /opt/dropbox/ and /tmp.
#
# https://bbs.archlinux.org/viewtopic.php?id=191001
RUN mkdir -p /opt/dropbox/bin/ \
 && mv /opt/dropbox/.dropbox-dist/* /opt/dropbox/bin/ \
 && rm -rf /opt/dropbox/.dropbox-dist \
 && install -dm0 /opt/dropbox/.dropbox-dist \
 && chmod u-w /opt/dropbox/.dropbox-dist \
 && chmod o-w /tmp \
 && chmod g-w /tmp

# Create volumes
VOLUME ["/opt/dropbox/.dropbox", "/opt/dropbox/Dropbox"]

# Install init script and dropbox command line wrapper
COPY docker-entrypoint.sh /

# Set entrypoint and command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/dropbox/bin/dropboxd"]
