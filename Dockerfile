# syntax=docker/dockerfile:1
#
# Modpack Paste Server
# --------------------
# One container that runs a modded Minecraft server (itzg/minecraft-server) plus a
# tiny always-on HTTP status surface on top of the statically linked busybox httpd.
#
# Both base images are pinned by digest so a redeploy months from now builds the
# exact same Java runtime the server was tested on.

# ---- stage 1: a static busybox binary, used only for its httpd applet ----------
FROM busybox:1.36@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662 AS busybox

# ---- stage 2: the game server ------------------------------------------------
FROM itzg/minecraft-server:java21@sha256:96d1da46d7b59bce34e86d527fdcfdc92a9636e83fbf94a3bb279de6ae07c17c

LABEL org.opencontainers.image.title="Modpack Paste Server" \
      org.opencontainers.image.description="Paste a Modrinth modpack URL, get a running modded Minecraft server with a persistent world." \
      org.opencontainers.image.source="https://github.com/lNamelessl/modpack-paste-server"

USER root

COPY --from=busybox /bin/busybox /usr/local/bin/busybox
RUN chmod 0755 /usr/local/bin/busybox \
 && mkdir -p /opt/railway/www

COPY scripts/entrypoint.sh /opt/railway/entrypoint.sh
COPY www/index.html /opt/railway/www/index.html
COPY www/health /opt/railway/www/health

RUN chmod 0755 /opt/railway/entrypoint.sh \
 && chmod 0644 /opt/railway/www/index.html /opt/railway/www/health

# EULA=TRUE is a literal, not a prompt: deploying this template is the operator's
# acceptance of the Minecraft EULA on their own behalf (documented in the listing).
ENV EULA=TRUE \
    TZ=UTC \
    PORT=8080 \
    SERVER_PORT=25565 \
    MEMORY=6G

# 8080 = HTTP status surface (Railway healthcheck + human status page)
# 25565 = Minecraft game traffic (attach a TCP proxy)
# 25575 = RCON (attach a TCP proxy if you want an external console)
EXPOSE 8080 25565 25575

ENTRYPOINT ["/opt/railway/entrypoint.sh"]
