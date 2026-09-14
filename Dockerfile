FROM ubuntu:12.04

# Los repos de 12.04 ya no estan en archive.ubuntu.com, migraron a old-releases
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g; \
            s|http://security.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        /etc/apt/sources.list

RUN apt-get update && apt-get install -y --force-yes --no-install-recommends \
        openjdk-6-jdk \
        git-core gnupg flex bison gperf build-essential \
        zip unzip curl ca-certificates \
        zlib1g-dev libc6-dev \
        lib32ncurses5-dev ia32-libs lib32readline-gplv2-dev lib32z1-dev \
        x11proto-core-dev libx11-dev libgl1-mesa-dev \
        g++-multilib mingw32 tofrodos python-markdown \
        libxml2-utils xsltproc make ccache python \
    && rm -rf /var/lib/apt/lists/*

# make 3.81 y JDK 6 son requisitos duros de gingerbread; los 12.04 ya los traen
ENV JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH
ENV USE_CCACHE=1
ENV CCACHE_DIR=/ccache

WORKDIR /src
