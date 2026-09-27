# =========================================================================
# Client: curl com suporte a HTTP/3, HTTP/2, iperf3, tshark e Python
# =========================================================================

FROM ubuntu:24.04 AS builder

ARG QUICTLS_VERSION=openssl-3.1.4-quic1
ARG NGTCP2_VERSION=v1.6.0
ARG NGHTTP3_VERSION=v1.3.0
ARG CURL_VERSION=curl-8_10_1

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        autoconf \
        automake \
        libtool \
        pkg-config \
        libev-dev \
        libbrotli-dev \
        zlib1g-dev \
        libpsl-dev \
        libnghttp2-dev \
        cmake \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 1. quictls
RUN git clone --depth 1 -b ${QUICTLS_VERSION} \
        https://github.com/quictls/openssl.git quictls \
    && cd quictls \
    && ./config enable-tls1_3 \
        --prefix=/usr/local/quictls \
        --libdir=lib \
    && make -j"$(nproc)" \
    && make install_sw

# 2. ngtcp2
RUN git clone --depth 1 -b ${NGTCP2_VERSION} \
        https://github.com/ngtcp2/ngtcp2.git \
    && cd ngtcp2 \
    && autoreconf -fi \
    && PKG_CONFIG_PATH=/usr/local/quictls/lib/pkgconfig \
       ./configure \
        --prefix=/usr/local/ngtcp2 \
        --with-openssl \
    && make -j"$(nproc)" \
    && make install

# 3. nghttp3
RUN git clone --depth 1 --recurse-submodules -b ${NGHTTP3_VERSION} \
        https://github.com/ngtcp2/nghttp3.git \
    && cd nghttp3 \
    && autoreconf -fi \
    && ./configure \
        --prefix=/usr/local/nghttp3 \
    && make -j"$(nproc)" \
    && make install

# 4. curl com HTTP/2 + HTTP/3
RUN git clone --depth 1 -b ${CURL_VERSION} \
        https://github.com/curl/curl.git \
    && cd curl \
    && autoreconf -fi \
    && LDFLAGS="-Wl,-rpath,/usr/local/quictls/lib" \
       ./configure \
        --with-openssl=/usr/local/quictls \
        --with-ngtcp2=/usr/local/ngtcp2 \
        --with-nghttp3=/usr/local/nghttp3 \
        --with-nghttp2 \
        --prefix=/usr/local/curl-http3 \
    && make -j"$(nproc)" \
    && make install

# =========================================================================
# Estágio final
# =========================================================================

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        iperf3 \
        tshark \
        python3 \
        python3-pip \
        python3-venv \
        iproute2 \
        libev4 \
        libbrotli1 \
        libpsl5 \
        libnghttp2-14 \
        ca-certificates \
        iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/quictls /usr/local/quictls
COPY --from=builder /usr/local/ngtcp2 /usr/local/ngtcp2
COPY --from=builder /usr/local/nghttp3 /usr/local/nghttp3
COPY --from=builder /usr/local/curl-http3 /usr/local/curl-http3

ENV LD_LIBRARY_PATH="/usr/local/quictls/lib:/usr/local/ngtcp2/lib:/usr/local/nghttp3/lib:/usr/local/curl-http3/lib"
ENV PATH="/usr/local/curl-http3/bin:${PATH}"

RUN pip3 install --break-system-packages --no-cache-dir \
        pandas \
        matplotlib \
        numpy \
        scipy

WORKDIR /workspace

CMD ["/bin/bash"]
