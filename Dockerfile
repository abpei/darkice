# =============================================================================
# DarkIce multi-stage Docker build — debian:bookworm-slim, amd64 only
# =============================================================================
# Builder: compiles darkice 1.6 from source with autotools.
# Runtime: minimal image with only the binary + shared libs.
# Config:  /etc/darkice.cfg  — bind-mount at runtime.
#
# Usage:
#   docker build -t darkice .
#   docker run --rm -v ./darkice.cfg:/etc/darkice.cfg darkice
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1 — Builder
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        automake \
        libtool \
        pkg-config \
        git \
        ca-certificates \
        libmp3lame-dev \
        libvorbis-dev \
        libogg-dev \
        libflac-dev \
        libasound2-dev \
        libpulse-dev \
        libjack-dev \
        libsamplerate0-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone darkice at the v1.6 tag and build from source
# The repo layout nests the autotools source under darkice/trunk/
RUN git clone --depth 1 --branch v1.6 \
        https://github.com/rafael2k/darkice.git /src/darkice

WORKDIR /src/darkice/darkice/trunk

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr/local \
        --disable-nls \
    && make -j"$(nproc)" \
    && make install DESTDIR=/build

# ---------------------------------------------------------------------------
# Stage 2 — Runtime (minimal)
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libmp3lame0 \
        libvorbis0a \
        libvorbisenc2 \
        libvorbisfile3 \
        libogg0 \
        libflac12 \
        libasound2 \
        alsa-utils \
        libpulse0 \
        libjack-jackd2-0 \
        libsamplerate0 \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary + man page from builder
COPY --from=builder /build/usr/local/bin/darkice /usr/local/bin/darkice
COPY --from=builder /build/usr/local/share/man/man1/darkice.1 /usr/local/share/man/man1/darkice.1

# Config lives at /etc/darkice.cfg — users bind-mount it at runtime
# e.g.  docker run -v ./darkice.cfg:/etc/darkice.cfg darkice
# The binary looks for /etc/darkice.cfg by default, so no extra flag needed.

# amd64 only — no cross-compilation or multi-arch support
# No GUI or website files are included.

ENTRYPOINT ["darkice"]
