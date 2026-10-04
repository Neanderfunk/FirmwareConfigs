# Bauumgebung fuer Gluon 2021.1 / OpenWrt 19.07 (Sackgasse).
# OpenWrt 19.07 baut nicht mit aktuellen Host-Compilern (gcc 15 auf Ubuntu
# 26.04); der alte Buildhost war Ubuntu 20.04, deshalb hier dasselbe.
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Berlin
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gawk unzip libncurses5-dev zlib1g-dev libssl-dev \
      wget curl time git subversion python2 python-is-python2 python3 \
      python3-distutils rsync file perl patch bzip2 xz-utils ca-certificates \
      flex bison gettext libelf-dev lua5.1 locales \
 && locale-gen en_US.UTF-8 && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
