FROM oven/bun:distroless@sha256:3cc457ea32e90b9c87b1d134e89c072a986ee3adaed7063d35fef2fce90cc4a7 as bun
FROM denoland/deno:bin@sha256:18d72c43e4b91c81e824e368e8eb15c67b481e669c5151dc3902cf113c87c4b7 AS deno

FROM ghcr.io/actions/actions-runner:latest@sha256:45f609ab5bd691735dbb25e3636db2f5142fcd8f17de635424f2e7cbd3e16bc9 as base

FROM registry.access.redhat.com/ubi9/ubi@sha256:66233eebd72bb5baa25190d4f55e1dc3fff3a9b77186c1f91a0abdb274452072 as builder
# Grab anything we can't get via other means

RUN dnf install -y \
    jq \
    && dnf clean all

ENV WORKDIR=/work

RUN mkdir -p ${WORKDIR}
WORKDIR ${WORKDIR}

COPY --chown=root:0 fetch-externals.sh ${WORKDIR}/
RUN cd ${WORKDIR} && \
    ./fetch-externals.sh

FROM registry.access.redhat.com/ubi9/ubi@sha256:66233eebd72bb5baa25190d4f55e1dc3fff3a9b77186c1f91a0abdb274452072

# see: https://github.com/actions/runner/blob/main/images/Dockerfile
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

ENV BIN_DIR=/usr/bin
ENV UID=1001
ENV GID=0
ENV USERNAME="runner"

# Add deps from docker images
COPY --from=bun     --chown=root:0 /usr/local/bin/bun ${BIN_DIR}/bun
COPY --from=deno    --chown=root:0 /deno ${BIN_DIR}/deno
COPY --from=builder --chown=root:0 /work/ko/ko ${BIN_DIR}/ko

# Adapted from https://github.com/bbrowning/github-runner/blob/master/Dockerfile
RUN dnf -y upgrade --security && \
    dnf -y --setopt=skip_missing_names_on_install=False install \
    git git-lfs golang jq unzip wget zstd && \
    dnf -y --setopt=skip_missing_names_on_install=False module install nodejs:20/common && \
    dnf clean all

# Setup user/dirs
RUN useradd -m $USERNAME -u $UID && \
    usermod -aG $GID $USERNAME

COPY --from=base --chown=${UID}:${GID} /home/runner /home/${USERNAME}_base

# Install runner deps
WORKDIR /home/${USERNAME}_base
RUN /home/${USERNAME}_base/bin/installdependencies.sh

# Inject sudo shim
COPY --chown=root:root ./sudoShim.sh ${BIN_DIR}/sudo

# Inject entrypoint
COPY --chown=${UID}:${GID} ./entrypoint.sh /home/runner_base/entrypoint.sh

USER $USERNAME

WORKDIR /home/${USERNAME}

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/home/runner_base/entrypoint.sh"]

