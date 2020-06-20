# Compiler Image
# --------------------------------------------------------------------------
FROM centos:8 AS compiler

# install dependencies
RUN dnf update -y
RUN dnf install git gcc gcc-c++ gmp-devel make tar wget zlib-devel -y
RUN dnf install systemd-devel ncurses-devel ncurses-compat-libs -y

# get cabal
ADD https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal-install.tar.xz
RUN tar -xf cabal-install.tar.xz && rm cabal-install.tar.xz cabal.sig
RUN mv cabal /usr/local/bin

RUN cabal update

# install ghc
ADD https://downloads.haskell.org/~ghc/8.6.5/ghc-8.6.5-x86_64-centos7-linux.tar.xz ghc.tar.xz
RUN tar -xf ghc.tar.xz
RUN cd ghc-8.6.5 && ./configure && make install

# clone cardano-node
ARG NODE_VERSION
ARG NODE_REPOSITORY
ARG NODE_BRANCH

RUN git clone -b $NODE_BRANCH --recurse-submodules $NODE_REPOSITORY cardano-node
WORKDIR cardano-node
RUN git fetch && git fetch --tags
RUN git checkout $NODE_VERSION
RUN git submodule update

# compile
RUN mkdir -p /binaries/
RUN cabal build all --symlink-bindir=/binaries/
# deal with ignored bin directory argument
RUN cp -L "/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.6.5/cardano-cli-${NODE_VERSION}/x/cardano-cli/build/cardano-cli/cardano-cli" /binaries/
RUN cp -L "/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.6.5/cardano-node-${NODE_VERSION}/x/cardano-node/build/cardano-node/cardano-node" /binaries/

# Main Image
# -------------------------------------------------------------------------
FROM centos:8

# Documentation
ENV DFILE_VERSION "1.2"

# Documentation
LABEL maintainer="Kevin Haller <keivn.haller@outofbits.com>"
LABEL version="${DFILE_VERSION}-${NODE_VERSION}"
LABEL description="Blockchain node for Cardano (implemented in Haskell)."

COPY --from=compiler /binaries/cardano-node /usr/local/bin/
COPY --from=compiler /binaries/cardano-cli /usr/local/bin/

ENTRYPOINT ["cardano-node"]
