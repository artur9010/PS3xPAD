FROM debian:bookworm

ARG PS3TOOLCHAIN_REF=master
ARG PSL1GHT_REF=master
ARG BUILD_JOBS=12
# Path to the Sony PS3 SDK tarball. Can be either:
#   1. A local file (mounted at /sdk/PS3_SDK.tar.gz or similar)
#   2. A URL (set SDK_URL env var or use default)
#   3. Already extracted at /sdk/ (if SDK_TARBALL=skip)
ARG SDK_TARBALL=/sdk/PS3_SDK.tar.gz
ARG SDK_URL=
ARG CELL_SDK=/opt/cell

ENV PS3DEV=/usr/local/ps3dev
ENV PSL1GHT=/usr/local/ps3dev/psl1ght
ENV PS3=/data
ENV CELL_SDK=${CELL_SDK}
ENV CELL_TARGET=${CELL_SDK}/target
ENV PATH=${CELL_SDK}/host/bin:${CELL_SDK}/host/ppu/bin:${CELL_SDK}/host/spu/bin:/usr/local/ps3dev/bin:/usr/local/ps3dev/ppu/bin:/usr/local/ps3dev/spu/bin:$PATH
ENV MAKEFLAGS=-j${BUILD_JOBS}

RUN apt-get update && apt-get install -y --no-install-recommends \
    zlib1g-dev \
    autoconf \
    automake \
    bison \
    build-essential \
    bzip2 \
    ca-certificates \
    clang \
    file \
    flex \
    git \
    libelf-dev \
    libgmp-dev \
    libncurses5-dev \
    libssl-dev \
    libtool \
    libtool-bin \
    libz-dev \
    make \
    patch \
    pkg-config \
    python3 \
    python-is-python3 \
    subversion \
    texinfo \
    wget \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

# Install Sony PS3 SDK
# The SDK is expected to be provided as a tarball at ${SDK_TARBALL}
# or as a URL via ${SDK_URL}. If the SDK is already extracted at
# ${CELL_SDK}, this step is skipped.
RUN if [ -d "${CELL_SDK}" ] && [ -f "${CELL_SDK}/host/bin/ppu-lv2-gcc" ]; then \
      echo "Sony PS3 SDK already installed at ${CELL_SDK}"; \
    elif [ -f "${SDK_TARBALL}" ]; then \
      echo "Installing Sony PS3 SDK from ${SDK_TARBALL}"; \
      mkdir -p /opt && cd /opt && tar xzf "${SDK_TARBALL}" && \
      if [ -d /opt/cell_sdk_* ]; then mv /opt/cell_sdk_* ${CELL_SDK}; fi; \
    elif [ -n "${SDK_URL}" ]; then \
      echo "Downloading Sony PS3 SDK from ${SDK_URL}"; \
      mkdir -p /opt && cd /opt && wget -O sdk.tar.gz "${SDK_URL}" && \
      tar xzf sdk.tar.gz && \
      if [ -d /opt/cell_sdk_* ]; then mv /opt/cell_sdk_* ${CELL_SDK}; fi; \
    else \
      echo ""; \
      echo "ERROR: Sony PS3 SDK not found!"; \
      echo "Provide it via one of:"; \
      echo "  1. Mount it as a volume: docker run -v /path/to/PS3_SDK.tar.gz:/sdk/PS3_SDK.tar.gz"; \
      echo "  2. Set SDK_URL when building: docker build --build-arg SDK_URL=https://..."; \
      echo "  3. Extract it to a host dir and mount: docker run -v /host/sdk:/opt/cell"; \
      echo ""; \
      exit 1; \
    fi

# Verify SDK installation
RUN ls -la ${CELL_SDK}/host/bin/ppu-lv2-gcc 2>/dev/null || \
    ls -la ${CELL_SDK}/host/ppu/bin/ppu-lv2-gcc 2>/dev/null || \
    (echo "ppu-lv2-gcc not found in expected locations"; exit 1)

# Also build PSL1GHT and open-source scetool as fallback
WORKDIR /opt
RUN git clone --depth 1 --branch "$PS3TOOLCHAIN_REF" https://github.com/ps3dev/ps3toolchain.git \
  && cd ps3toolchain \
  && ./toolchain.sh 001 002 004 005 006

RUN cd /opt/ps3toolchain \
  && ./toolchain.sh 008

RUN git clone --depth 1 https://github.com/spacemanspiff/oscetool.git /opt/oscetool \
  && cd /opt/oscetool \
  && make -j${BUILD_JOBS} \
  && cp oscetool /usr/local/bin/oscetool \
  && ln -sf /usr/local/bin/oscetool /usr/local/bin/scetool

# Use Sony SDK's scetool if available, otherwise fallback to oscetool
RUN if [ -f "${CELL_SDK}/host/bin/scetool" ]; then \
      ln -sf ${CELL_SDK}/host/bin/scetool /usr/local/bin/scetool-sony; \
      echo "Sony SDK scetool installed"; \
    fi

WORKDIR /work
COPY . /work

# Ensure ps3keys submodule content is available (clone if not in build context)
RUN if [ ! -f /work/ext_sources/ps3keys/app-key-355 ]; then \
      git clone --depth 1 https://github.com/codyps/ps3keys.git /work/ext_sources/ps3keys; \
    fi

RUN PS3KEYS_DIR=/work/ext_sources/ps3keys python3 /work/scripts/build_scetool_keys.py \
  && mkdir -p /data \
  && cp /work/ext_sources/ps3keys/keys /data/keys

# Build the plugin using Sony SDK
RUN make -j${BUILD_JOBS} -C src

CMD ["make", "-j12", "-C", "src"]
