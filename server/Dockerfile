# =========================================================================
# NGINX com suporte a HTTP/1.1, HTTP/2 e HTTP/3 (QUIC)
# Compilado a partir do código-fonte com "quictls" (fork do OpenSSL com
# suporte às APIs de QUIC exigidas pelo NGINX). A imagem oficial do NGINX
# no Docker Hub NÃO vem com ngx_http_v3_module habilitado, então a
# compilação manual é necessária.
#
# OBS: as versões abaixo são um ponto de partida razoável em 2026; se o
# build falhar por incompatibilidade, ajuste NGINX_VERSION / QUICTLS_VERSION
#iproute2 \# para as combinações testadas na documentação oficial do NGINX QUIC.
# =========================================================================
FROM ubuntu:24.04 AS builder

ARG NGINX_VERSION=1.27.2
ARG QUICTLS_VERSION=openssl-3.1.4-quic1

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        wget \
        ca-certificates \
        libpcre3-dev \
        zlib1g-dev \
        perl \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 1. quictls: OpenSSL com suporte às APIs de QUIC
RUN git clone --depth 1 -b ${QUICTLS_VERSION} \
        https://github.com/quictls/openssl.git quictls

# 2. Código-fonte do NGINX
RUN wget -q https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xzf nginx-${NGINX_VERSION}.tar.gz

# 3. Compila NGINX com HTTP/3, linkando estaticamente contra o quictls
WORKDIR /build/nginx-${NGINX_VERSION}
RUN ./configure \
        --prefix=/usr/local/nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-openssl=../quictls \
    && make -j"$(nproc)" \
    && make install

# =========================================================================
# Estágio final: imagem enxuta, só com o binário compilado + libs
# =========================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpcre3 \
        zlib1g \
        openssl \
        iperf3 \
        ca-certificates \
        coreutils \
	iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/nginx /usr/local/nginx

RUN mkdir -p /usr/local/nginx/certs /usr/local/nginx/html/files/objects

COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PATH="/usr/local/nginx/sbin:${PATH}"

EXPOSE 80/tcp 443/tcp 443/udp 5201/tcp

ENTRYPOINT ["/entrypoint.sh"]
