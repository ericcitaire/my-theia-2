FROM ubuntu:groovy

ENV DEBIAN_FRONTEND noninteractive

RUN yes | unminimize \
 && apt-get update \
 && apt-get install -yq \
      man-db manpages manpages-posix \
      sudo zsh net-tools htop gpg wget curl xz-utils git build-essential libc6 vim make gcc gdb llvm runc podman \
      python3-pip libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev liblzma-dev libssl-dev zlib1g-dev \
      libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev tk-dev \
      openjdk-8-jdk maven \
      jq xmlstarlet \
 && rm -rf /var/lib/apt/lists/*

# START Node
# https://github.com/nodejs/docker-node/blob/4e8a6d0f08491ebf91b542e49206edea81fb3541/12/buster/Dockerfile

ENV NODE_VERSION 12.22.1

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  # smoke tests
  && node --version \
  && npm --version

ENV YARN_VERSION 1.22.5

RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  # smoke test
  && yarn --version

# END Node

ARG user=theia
ARG group=theia

RUN adduser --disabled-password --gecos '' ${user} \
 && adduser ${user} sudo \
 && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
 && mkdir -p /workspace \
 && chown -R ${user}:${group} /workspace

USER ${user}
ENV HOME=/home/${user}

# START Python
# https://github.com/gitpod-io/workspace-images/blob/abd6818f4a9db3b2e7c7d17d4af5fdba17b0ccb4/full/Dockerfile#L155-L173

ENV PATH=$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH
RUN curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash \
    && pyenv update \
    && pyenv install 2.7.18 \
    && pyenv install 3.8.10 \
    && pyenv global 2.7.18 3.8.10 \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir --upgrade \
        setuptools wheel virtualenv pipenv pylint rope flake8 \
        mypy autopep8 pep8 pylama pydocstyle bandit notebook \
        twine \
    && sudo rm -rf /tmp/*
ENV PYTHONUSERBASE=/workspace/.pip-modules \
    PIP_USER=yes

# END Python

# START Theia
# https://github.com/theia-ide/theia-apps/blob/d329db260cc8e96759241198153d9d3fd731f32e/theia-full-docker/Dockerfile#L109-L123

COPY --chown=${user}:${group} package.json /opt/theia/package.json

RUN cd /opt/theia \
 && yarn --pure-lockfile \
 && NODE_OPTIONS="--max_old_space_size=4096" yarn theia build \
 && yarn theia download:plugins \
 && yarn --production \
 && yarn autoclean --init \
 && echo *.ts >> .yarnclean \
 && echo *.ts.map >> .yarnclean \
 && echo *.spec.* >> .yarnclean \
 && yarn autoclean --force \
 && yarn cache clean

# END Theia

RUN curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" | sh - \
 && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k \
 && true \
 && $HOME/.oh-my-zsh/custom/themes/powerlevel10k/gitstatus/install \
 && sed -i 's|^ZSH_THEME=.*$|ZSH_THEME="powerlevel10k/powerlevel10k"|' $HOME/.zshrc \
 && printf '\n\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n\n' >> $HOME/.zshrc \
 && printf '\n\n# Force ZSH\nif [ "$SHLVL" -eq 1 ] ; then echo "Oops, bash is here" && exec zsh ; fi\n\n' >> $HOME/.bashrc

COPY --chown=${user}:${group} dot-zshrc ${HOME}/.zshrc
COPY --chown=${user}:${group} dot-zshrc.d/ ${HOME}/.zshrc.d/

EXPOSE 3000

ENV SHELL=/usr/bin/zsh \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PATH=${HOME}/.local/bin:${PATH}

VOLUME /workspace
WORKDIR /workspace

ENTRYPOINT [ "/usr/bin/zsh", "-c", "node /opt/theia/src-gen/backend/main.js /workspace --app-project-path=/opt/theia --plugins=local-dir:/opt/theia/plugins --hostname=0.0.0.0" ]
