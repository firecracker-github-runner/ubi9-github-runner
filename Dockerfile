FROM oven/bun:distroless@sha256:7d3a4d979da0b40ddfad6bb23b044006d96a39fd9b256c990f54d26c7e8644f7 as bun

FROM summerwind/actions-runner@sha256:0358dc81feccc522fd94f7c86dd8733499320159f880671e8fcc9362d7b90349 as default-actions-runner

FROM denoland/deno:bin@sha256:7da859b3e0bca7229bd5baef44c11ec6ba32caa4af2aba5dd3945d9297009cd2 AS deno

FROM registry.access.redhat.com/ubi9/ubi@sha256:66233eebd72bb5baa25190d4f55e1dc3fff3a9b77186c1f91a0abdb274452072

# Override these when creating the container.
ENV GITHUB_PAT ""
ENV GITHUB_APP_ID ""
ENV GITHUB_APP_INSTALL_ID ""
ENV GITHUB_APP_PEM ""
ENV GITHUB_OWNER ""
ENV GITHUB_REPOSITORY ""

ENV RUNNER_WORKDIR /runner/_work
ENV RUNNER_ASSETS_DIR=/home/${USERNAME}/_assets
ENV RUNNER_TOOL_CACHE=/runner/_tool_cache
ENV RUNNER_GROUP ""
ENV RUNNER_LABELS ""
ENV EPHEMERAL ""

ENV BIN_DIR=/usr/bin

# Adapted from https://github.com/bbrowning/github-runner/blob/master/Dockerfile
RUN dnf -y upgrade --security && \
    dnf -y --setopt=skip_missing_names_on_install=False install \
    git git-lfs jq hostname procps unzip && \
    dnf -y --setopt=skip_missing_names_on_install=False module install nodejs:20/common && \
    dnf clean all

# Add Deno to the PATH
COPY --from=deno --chown=root:0 /deno ${BIN_DIR}/deno

# Add Bun to the PATH
COPY --from=bun --chown=root:0 /usr/local/bin/bun ${BIN_DIR}/bun

# The UID env var should be used in child Containerfile.
ENV UID=1000
ENV GID=0
ENV USERNAME="runner"

# Create our user and their home directory
RUN useradd -m $USERNAME -u $UID
# This is to mimic the OpenShift behaviour of adding the dynamic user to group 0.
RUN usermod -G 0 $USERNAME
ENV HOME /home/${USERNAME}
WORKDIR /home/${USERNAME}

# pnpm
ENV PNPM_STORE_PATH ${HOME}/.pnpm-store 
RUN npm install -g pnpm && \
    pnpm config set store-dir ${PNPM_STORE_PATH}

RUN mkdir -p ${RUNNER_ASSETS_DIR}
COPY --chown=root:0 get-runner-release.sh ${BIN_DIR}/
RUN cd ${RUNNER_ASSETS_DIR} && \
    ${BIN_DIR}/get-runner-release.sh && \
    ./bin/installdependencies.sh && \
    mv ./externals ./externalstmp && \
    cd -

COPY --from=default-actions-runner --chown=root:0 /usr/bin/dumb-init /usr/bin/entrypoint.sh /usr/bin/startup.sh  /usr/bin/logger.sh  /usr/bin/graceful-stop.sh /usr/bin/update-status ${BIN_DIR}/

COPY --from=default-actions-runner --chown=root:0 /etc/arc/hooks/ /etc/arc/hooks/

# RUN chmod g+x ${BIN_DIR}/dumb-init ${BIN_DIR}/entrypoint.sh ${BIN_DIR}/startup.sh ${BIN_DIR}/logger.sh ${BIN_DIR}/graceful-stop.sh ${BIN_DIR}/update-status

# Set permissions so that we can allow the openshift-generated container user to access home.
# https://docs.openshift.com/container-platform/3.3/creating_images/guidelines.html#openshift-container-platform-specific-guidelines
RUN chown -R ${USERNAME}:0 /home/${USERNAME}/ && \
    chgrp -R 0 /home/${USERNAME}/ && \
    chmod -R g=u /home/${USERNAME}/

USER $USERNAME

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]

