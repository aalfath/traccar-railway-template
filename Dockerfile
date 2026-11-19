# Traccar GPS tracking server, packaged for Railway.
# Upstream image pinned by version and digest (multi-arch index, Alpine flavour).
FROM traccar/traccar:6.17.0-alpine@sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1

# Small wrapper: writes conf/traccar.xml from Railway's variables (Postgres, PORT,
# public domain), then creates the first administrator from TRACCAR_ADMIN_EMAIL /
# TRACCAR_ADMIN_PASSWORD so the instance never starts open for anyone to claim.
COPY --chmod=755 railway-start.sh /opt/traccar/railway-start.sh

WORKDIR /opt/traccar
ENTRYPOINT ["/opt/traccar/railway-start.sh"]
CMD []
