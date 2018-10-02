FROM python:3.6.5-slim-stretch
LABEL maintainer="WST Meteogroup <wmt@meteogroup.com>"

##### Initialize
RUN ln -sf bash /bin/sh

##### Install system libraries
# Authenticate custom apt repos
RUN apt-get -qy update
RUN apt-get -qy install --no-install-recommends gnupg
COPY llvm-snapshot.gpg.key /tmp/llvm-snapshot.gpg.key
RUN apt-key add /tmp/llvm-snapshot.gpg.key
# Retrieve package lists
RUN echo 'deb http://apt.llvm.org/stretch/ llvm-toolchain-stretch-6.0 main' >> /etc/apt/sources.list.d/llvm.list
RUN echo 'deb-src http://apt.llvm.org/stretch/ llvm-toolchain-stretch-6.0 main' >> /etc/apt/sources.list.d/llvm.list
RUN apt-get -qy update
# Install packages
ARG BUILD_DEB_PKGS='gcc git g++ libc6-dev llvm-6.0-dev make'
ARG RUNTIME_DEB_PKGS='llvm-6.0'
RUN apt-get -qy install --no-install-recommends $BUILD_DEB_PKGS $RUNTIME_DEB_PKGS

##### Configure LLVM
ENV LLVM_CONFIG=/usr/lib/llvm-6.0/bin/llvm-config

##### Build and install GDAL
WORKDIR /tmp
# Use our own fork because of GRIB2 longitude range, exclude history before tag v2.3.1
COPY . gdal
# RUN git clone --branch scado --shallow-exclude=v2.3.1 --single-branch https://github.com/MeteoGroup/gdal.git
WORKDIR /tmp/gdal
RUN git checkout aeabb8d22c8101b4e0f1d0be0827f77e57b9b552
WORKDIR /tmp/gdal/gdal
RUN ./configure
RUN make
RUN make install
RUN ldconfig

##### Installl python packages
COPY requirements.txt /tmp/requirements.txt
COPY python-utils /tmp/python-utils
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    cd /tmp/python-utils/ && pip install --no-cache-dir .
WORKDIR /tmp
# Installing gdal via requirements.txt leads to an import error: ModuleNotFoundError: No module named '_gdal_array'
RUN pip install --no-cache-dir gdal==2.3.1
# Installed after the other pip packages because of broken dependencies.
# Our own fork because of performance adjustments and removed matplotlib dependency.
RUN pip install --no-cache-dir git+git://github.com/meteogroup/pykrige.git@b77d7623ecfcd569b945bbb179f12287e7d27275#egg=pykrige

##### Cleanup
RUN rm -rf /tmp/gdal
RUN apt-get purge -y --auto-remove $BUILD_DEB_PKGS
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /var/log/dpkg.log
