FROM oven/bun:distroless@sha256:3cc457ea32e90b9c87b1d134e89c072a986ee3adaed7063d35fef2fce90cc4a7 as bun
FROM denoland/deno:bin@sha256:18d72c43e4b91c81e824e368e8eb15c67b481e669c5151dc3902cf113c87c4b7 AS deno
FROM golang:latest@sha256:450e3822c7a135e1463cd83e51c8e2eb03b86a02113c89424e6f0f8344bb4168 as golang

FROM ghcr.io/actions/actions-runner:latest@sha256:45f609ab5bd691735dbb25e3636db2f5142fcd8f17de635424f2e7cbd3e16bc9 as base

FROM ubuntu:jammy@sha256:77906da86b60585ce12215807090eb327e7386c8fafb5402369e421f44eff17e as builder
# Grab anything we can't get via other means

# apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y curl jq

ENV WORKDIR=/work
ENV BIN_OUT=/work/bin
ENV GO_DIR=/work/go

RUN mkdir -p ${WORKDIR} && \
    mkdir -p ${BIN_OUT}
WORKDIR ${WORKDIR}

COPY --from=bun     --chown=root:0 /usr/local/bin/bun /usr/local/bin/bunx ${BIN_OUT}/
COPY --from=deno    --chown=root:0 /deno ${BIN_OUT}/

COPY --chown=root:0 build-bin.sh ${WORKDIR}/
RUN cd ${WORKDIR} && \
    ./build-bin.sh

FROM ubuntu:jammy@sha256:77906da86b60585ce12215807090eb327e7386c8fafb5402369e421f44eff17e
# see: https://github.com/actions/runner/blob/main/images/Dockerfile

ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

ENV BIN_DIR=/usr/bin
ENV UID=1001
ENV GID=0
ENV USERNAME="runner"
ENV BASE_DIR=/home/${USERNAME}_base

# Add deps from images
COPY --from=golang  --chown=root:0 /usr/local/go /usr/local/
COPY --from=builder --chown=root:0 /work/bin/* ${BIN_DIR}/

# Add golang to PATH
ENV PATH=/usr/local/go:${PATH}

# Setup runner
COPY --from=base --chown=root:0 /home/runner ${BASE_DIR}

# Install deps
RUN useradd -m $USERNAME -u $UID && \
    usermod -aG $GID $USERNAME && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    git \
    git-lfs \
    unzip \
    wget \
    zstd && \
    ${BASE_DIR}/bin/installdependencies.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Inject entrypoint
COPY --chown=root:0 ./entrypoint.sh ${BASE_DIR}/

USER $USERNAME
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/home/runner_base/entrypoint.sh"]

