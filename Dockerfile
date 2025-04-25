# Stage 1: Build all dependencies and Tor
FROM alpine:latest AS builder

# Base tools
RUN apk add --no-cache \
    build-base \
    perl \
    cmake \
    nasm \
    git \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    wget \
    linux-headers

# Versions
ARG ZLIB_VERSION=1.3.1
ARG LIBEVENT_VERSION=2.1.12-stable
ARG OPENSSL_VERSION=1.1.1w
ARG TOR_VERSION=tor-0.4.8.16

# Installation prefixes
ENV PREFIX_DIR=/usr/local
ENV ZLIB_DIR=${PREFIX_DIR}
ENV LIBEVENT_DIR=${PREFIX_DIR}
ENV OPENSSL_DIR=${PREFIX_DIR}

WORKDIR /build

# Statisches Zlib kompilieren
RUN wget https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz && \
    tar xzf zlib-${ZLIB_VERSION}.tar.gz && \
    cd zlib-${ZLIB_VERSION} && \
    CFLAGS="-fPIC -O2" ./configure --static --prefix=${PREFIX_DIR} && \
    make -j$(nproc) && \
    make install

# Statische OpenSSL kompilieren
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./config no-shared no-dso --prefix=${OPENSSL_DIR} -fPIC && \
    make -j$(nproc) && \
    make install_sw

# Statische libevent kompilieren
RUN wget https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz && \
    tar xzf libevent-${LIBEVENT_VERSION}.tar.gz && \
    cd libevent-${LIBEVENT_VERSION} && \
    ./configure --disable-shared --enable-static CFLAGS="-fPIC -O2" --with-zlib=${ZLIB_DIR} && \
    make -j$(nproc) && \
    make install

# Tor clonen und bauen
RUN git clone https://gitlab.torproject.org/tpo/core/tor.git && \
    cd tor && \
    git checkout ${TOR_VERSION} && \
    ./autogen.sh && \
    ./configure \
        --disable-asciidoc \
        --disable-zstd \
        --disable-lzma \
        --disable-manpage \
        --disable-html-manual \
        --enable-static-tor \
        --disable-module-dirauth \
        --disable-unittests \
        --disable-system-torrc \
        --disable-tool-name-check \
        --with-libevent-dir=${LIBEVENT_DIR} \
        --with-openssl-dir=${OPENSSL_DIR} \
        --with-zlib-dir=${ZLIB_DIR} \
        CFLAGS="-static -O2 -I${PREFIX_DIR}/include" \
        LDFLAGS="-static -L${PREFIX_DIR}/lib" && \
    make -j$(nproc)

# Copy entrypoint and config into builder and set permissions
RUN mkdir -p /build/scripts 
COPY torrc.default /build/scripts/

# Stage 2: Minimal scratch container
FROM scratch

LABEL org.opencontainers.image.source=https://github.com/sldna/tor-static
LABEL org.opencontainers.image.vendor="sldna"
LABEL org.opencontainers.image.authors="Sven Lidynia"
LABEL org.opencontainers.image.description="static linked Tor proxy in a scratch container"
LABEL org.opencontainers.image.licenses=MIT


WORKDIR /tor

# Binaries and scripts
COPY --from=builder /build/tor/src/app/tor .
COPY --from=builder /build/scripts/torrc.default /torrc
ENTRYPOINT ["/tor/tor", "-f", "/torrc"]

# Healthcheck: prüft Konfig
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/tor/tor", "--verify-config", "--hush"]
