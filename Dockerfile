FROM ubuntu:14.04

# The i386, and installs of binutils-multiarch gcc-multilib zlib1g:i386 are workarounds for the 32 bit Android toolchain
RUN \
  dpkg --add-architecture i386

# Install.
RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  # DIABLO \
  apt-get install -y build-essential && \
  apt-get install -y software-properties-common && \
  apt-get install -y byobu curl git htop man unzip vim wget && \
  apt-get install -y cmake bison flex && \
  apt-get install -y binutils-multiarch gcc-multilib zlib1g:i386 && \
  # ACTC \
  apt-get install -y python python-pip && \
  pip install doit==0.29.0 && \
  # ONLINE TECHNIQUES \
  apt-get install -y nginx php5-fpm python-dev libmysqlclient18 libmysqlclient-dev openjdk-7-jre binutils-dev tree
# Warning: MySQL gets installed later on, because first the default pw is set

# TODO: clone outside container?
RUN \
  mkdir -p /opt/ && \
  cd /opt/

COPY files/framework/ /opt/framework

RUN \
  mkdir -p /opt/framework/diablo/build/ && \
  cd /opt/framework/diablo/build/ && \
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/framework/diablo/install .. && \
  make && \
  make install && \
  ln -s /opt/framework/diablo/install/bin /opt/diablo

# TODO: more advanced scripts that do symlinking might be needed eventually in that last step above!

COPY support/diablo/ /tmp/

# TODO: just unpack the tar OUTSIDE the container, and copy it in with COPY?
# TODO: optionally rebuild 3rd_party from scratch

RUN \
  wget -O /tmp/linux-gcc-4.8.1.tar.bz2 https://diablo.elis.ugent.be/sites/diablo/files/toolchains/diablo-binutils-2.23.2-gcc-4.8.1-eglibc-2.17.tar.bz2 && \
  mkdir -p /opt/diablo-gcc-toolchain && \
  cd /opt/diablo-gcc-toolchain && \
  tar xvf /tmp/linux-gcc-4.8.1.tar.bz2 && \
  /tmp/patch_gcc.sh /opt/diablo-gcc-toolchain/

RUN \
  wget -O /tmp/android-gcc-4.8.tar.bz2 https://diablo.elis.ugent.be/sites/diablo/files/toolchains/diablo-binutils-2.23.2-gcc-4.8.1-android-API-18.tar.bz2 && \
  mkdir -p /opt/diablo-android-gcc-toolchain && \
  cd /opt/diablo-android-gcc-toolchain && \
  tar xvf /tmp/android-gcc-4.8.tar.bz2 && \
  /tmp/patch_gcc.sh /opt/diablo-android-gcc-toolchain/

RUN \
  mkdir -p /opt/diablo/obj/ && \
  cd /opt/framework/diablo/self-profiling && \
  ./generate.sh /opt/diablo-gcc-toolchain/bin/arm-diablo-linux-gnueabi-cc printarm_linux.o arm && \
  make && \
  cp printarm_linux.o /opt/diablo/obj/ && \
  ./generate.sh /opt/diablo-android-gcc-toolchain/bin/arm-linux-androideabi-gcc printarm_android.o arm && \
  make && \
  cp printarm_android.o /opt/diablo/obj/

RUN \
  ln -s /opt/framework/actc/src/ /opt/ACTC


# TODO: clone into framework?
# TODO: rebuild the object files automatically

RUN \
  mkdir -p /opt/3rd_party && \
  cd /opt/3rd_party && \
  wget https://diablo.elis.ugent.be/sites/diablo/files/prebuilt/curl-7.45.0-prebuilt.tar.bz2 && \
  wget https://diablo.elis.ugent.be/sites/diablo/files/prebuilt/libwebsockets-1.5-prebuilt.tar.bz2 && \
  wget https://diablo.elis.ugent.be/sites/diablo/files/prebuilt/openssl-1.0.2d-prebuilt.tar.bz2 && \
  tar xvf curl-7.45.0-prebuilt.tar.bz2 && \ 
  tar xvf libwebsockets-1.5-prebuilt.tar.bz2 && \
  tar xvf openssl-1.0.2d-prebuilt.tar.bz2 

COPY support/online/mysql-pre-setup.sh /tmp/mysql-pre-setup.sh

# This has to run before the mysql-server installs as it sets the default password
RUN \
 /tmp/mysql-pre-setup.sh && \
  apt-get install -y mysql-client mysql-server 

RUN \
  cd /opt/framework && \
  ln -s /opt/framework/code-guards /opt/codeguard && \
  ln -s /opt/framework/annotation_extractor /opt/annotation_extractor && \
  /opt/framework/ascl/build.sh && \
  /opt/framework/accl/build.sh && \
  find /opt/framework/code-mobility/ | grep Makefile | xargs sed --in-place "s/-Werror//" && \
  mkdir -p /opt/online_backends/code_mobility/ && \
  mkdir -p /opt/ASCL && \
  ln -s /opt/framework/ascl/src /opt/ASCL/src && \
  ln -s /opt/framework/ascl/src /opt/ASCL/include && \
  ln -s /opt/framework/ascl/src/aspire-portal /opt/ASCL/aspire-portal && \
  ln -s /opt/framework/ascl/prebuilt /opt/ASCL/obj && \
  ln -s /opt/ASCL/obj/linux_x86 /opt/ASCL/obj/serverlinux && \
  ln -s /opt/framework/code-mobility /opt/code_mobility && \
  ln -s /opt/framework/remote-attestation /opt/RA && \
  ln -s /opt/code_mobility/prebuilt/ /opt/code_mobility/downloader && \
  ln -s /opt/code_mobility/prebuilt/ /opt/code_mobility/binder && \
  ln -s /opt/framework/accl/ /opt/ACCL && \
  ln -s /opt/framework/accl/prebuilt/ /opt/ACCL/obj && \
  ln -s /opt/framework/accl/src/ /opt/ACCL/include && \
  cd /opt/framework/code-mobility/src/mobility_server && \
  cd - && \
  ln -s /opt/code_mobility/scripts/deploy_application.sh /opt/code_mobility/ && \
  chmod a+x /opt/code_mobility/deploy_application.sh && \
  sed --in-place -e 's#/opt/code_mobility/mobility_server/mobility_server#/opt/code_mobility/prebuilt/bin/x86/mobility_server#' /opt/ASCL/aspire-portal/backends.json && \
  /opt/framework/code-mobility/build.sh

RUN \
  /etc/init.d/mysql restart || true && \
  /opt/framework/renewability/build.sh && \
  ln -s /opt/framework/renewability /opt/renewability && \
  chmod a+x /opt/renewability/scripts/create_new_revision.sh && \
  /opt/renewability/setup/database_setup.sh

COPY support/online/nginx-default /etc/nginx/sites-available/default
COPY support/online/aspire_ascl.conf /etc/nginx/conf.d/aspire_ascl.conf

# TODO: this file is slightly patched for Docker (and also patches /opt/ASCL/aspire-portal/aspire-portal.ini): make them uniform!
COPY support/online/nginx-setup.sh /tmp/nginx-setup.sh

RUN \
  /tmp/nginx-setup.sh && \
  pip install uwsgi && \
  mkdir -p /opt/online_backends/code_mobility/

# EXPOSE 8088
EXPOSE 8080-8099
EXPOSE 18001

# For the RA-CM integration, this is needed ALSO for CM

RUN \
  /etc/init.d/mysql restart || true && \
  /opt/RA/setup/remote_attestation_setup.sh && \
  cd /opt/RA/obj && \
  ../setup/generate_racommons.sh -o .
