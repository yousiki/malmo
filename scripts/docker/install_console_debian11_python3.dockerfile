## Custom Dockerfile allowing remote display of Malmo installed using the pip3 Python wheel
FROM consol/debian-xfce-vnc:v2.0.4
ENV REFRESHED_AT="2026-01-13"

## Switch to root 
USER 0

# Keep downloaded packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Install apt packages (including Python 3.7 build dependencies)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    cmake \
    curl \
    dos2unix \
    ffmpeg \
    gh \
    git \
    gnupg \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libswresample-dev \
    libswscale-dev \
    lsb-release \
    pkg-config \
    rsync \
    software-properties-common \
    sudo \
    tk-dev \
    tmux \
    uuid-dev \
    vim \
    wget \
    xpra \
    xz-utils \
    zlib1g-dev \
    zstd

# Install Java 8
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add - && \
    echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-8-jdk

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/temurin-8-jdk-amd64
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> /root/.bashrc
# Test that JAVA_HOME is correct by running java -version
RUN ${JAVA_HOME}/bin/java -version

# Build and install Python 3.7 from source
# Python 3.7 is EOL but required by malmo pip package
ENV PYTHON37_VERSION=3.7.17
RUN cd /tmp && \
    wget https://www.python.org/ftp/python/${PYTHON37_VERSION}/Python-${PYTHON37_VERSION}.tgz && \
    tar xzf Python-${PYTHON37_VERSION}.tgz && \
    cd Python-${PYTHON37_VERSION} && \
    ./configure --enable-optimizations --prefix=/opt/python37 && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/Python-${PYTHON37_VERSION}*

# Create symlinks and setup Python 3.7
ENV PATH="/opt/python37/bin:$PATH"
RUN ln -sf /opt/python37/bin/python3.7 /usr/local/bin/python3 && \
    ln -sf /opt/python37/bin/python3.7 /usr/local/bin/python && \
    ln -sf /opt/python37/bin/pip3.7 /usr/local/bin/pip3 && \
    ln -sf /opt/python37/bin/pip3.7 /usr/local/bin/pip && \
    /opt/python37/bin/python3.7 -m pip install --upgrade pip setuptools wheel && \
    echo "export PATH=/opt/python37/bin:$PATH" >> /root/.bashrc

# Pass in --build-arg MALMOVERSION="x.x.x" to re-install
ARG MALMOVERSION=unknown

# Install dependencies using Python 3.7
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    /opt/python37/bin/pip3.7 install \
    future \
    jupyter \
    matplotlib \
    numpy \
    pillow \
    setuptools \
    tqdm

# TODO: Use latest version of malmo
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    /opt/python37/bin/pip3.7 install --index-url https://test.pypi.org/simple/ \
    "malmo==0.36.0"

# Set MALMO_XSD_PATH to download install location.
ENV MALMO_XSD_PATH=/root/MalmoPlatform/Schemas
# Download and build Minecraft mod
RUN cd /root && \
    /opt/python37/bin/python3.7 -c "import malmo.minecraftbootstrap;malmo.minecraftbootstrap.download(buildMod=True)" && \
    test -f /root/MalmoPlatform/VERSION && \
    echo "export MALMO_XSD_PATH=/root/MalmoPlatform/Schemas" >> /root/.bashrc

COPY ./console_startup.sh /root/console_startup.sh
RUN dos2unix /root/console_startup.sh && chmod +x /root/console_startup.sh
ENTRYPOINT ["/root/console_startup.sh"]
