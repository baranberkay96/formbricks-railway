# Formbricks' Cube image (distroless, no shell) with the Cube config and data model from the
# Formbricks repository (docker/cube at tag 6.2.2, AGPL-3.0) baked in instead of bind mounts.
ARG CUBE_IMAGE=ghcr.io/formbricks/cube:1.8.8-3@sha256:dbe4b87e37e54e634e8cb3e8b6fd1d5cb9e2d84fe6225abbec9cb715c71fe50e
FROM ${CUBE_IMAGE}
COPY cube.js /cube/conf/cube.js
COPY model/ /cube/conf/model/
