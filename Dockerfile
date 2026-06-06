FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        tar \
        tini \
        util-linux \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++6:i386 \
        zlib1g:i386 \
        libcurl4:i386 \
        libssl3:i386 \
        libncurses6:i386 \
        libsdl2-2.0-0:i386 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash steam \
    && mkdir -p /opt/steamcmd /opt/pzserver /data \
    && chown -R steam:steam /opt/steamcmd /opt/pzserver /data /home/steam

RUN curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar -xz -C /opt/steamcmd \
    && chown -R steam:steam /opt/steamcmd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 16261/udp
EXPOSE 16262/udp
EXPOSE 8766/udp
EXPOSE 8767/udp
EXPOSE 27015/tcp

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
