ARG UBUNTU_VERSION=22.04

FROM ubuntu:${UBUNTU_VERSION} AS build

ARG TZ=Etc/UTC
ARG DEBIAN_FRONTEND=noninteractive
ARG CTOOLS_BUILD="none"
ARG CTYPE="RelWithDebInfo"
ARG CSCRIPTS="static"
ARG CMODULES="static"
ARG CWITH_WARNINGS="ON"
ARG GIT_DISCOVERY_ACROSS_FILESYSTEM=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tzdata ca-certificates \
        build-essential ccache cmake clang git \
        curl unzip default-mysql-client openssl \
        default-libmysqlclient-dev libboost-all-dev libssl-dev \
        libmysql++-dev libreadline-dev zlib1g-dev \
        libbz2-dev libncurses5-dev \
    && ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /azerothcore

COPY CMakeLists.txt /azerothcore/CMakeLists.txt
COPY conf /azerothcore/conf
COPY deps /azerothcore/deps
COPY modules /azerothcore/modules
COPY src /azerothcore/src

WORKDIR /azerothcore/build

RUN --mount=type=cache,target=/ccache,sharing=locked \
    --mount=type=bind,target=/azerothcore/.git,source=.git \
    git config --global --add safe.directory /azerothcore \
    && cmake /azerothcore \
        -DCMAKE_INSTALL_PREFIX="/azerothcore/env/dist" \
        -DAPPS_BUILD="all" \
        -DTOOLS_BUILD="$CTOOLS_BUILD" \
        -DSCRIPTS="$CSCRIPTS" \
        -DMODULES="$CMODULES" \
        -DWITH_WARNINGS="$CWITH_WARNINGS" \
        -DCMAKE_BUILD_TYPE="$CTYPE" \
        -DCMAKE_CXX_COMPILER="clang++" \
        -DCMAKE_C_COMPILER="clang" \
        -DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
        -DCMAKE_C_COMPILER_LAUNCHER="ccache" \
        -DBoost_USE_STATIC_LIBS="ON" \
    && cmake --build . --config "$CTYPE" -j "$(($(nproc) + 1))" \
    && cmake --install . --config "$CTYPE"

FROM ubuntu:${UBUNTU_VERSION} AS runtime-base

ARG TZ=Etc/UTC
ARG DEBIAN_FRONTEND=noninteractive

ENV PATH="/azerothcore/env/dist/bin:${PATH}" \
    CONF_DIR="/azerothcore/env/dist/etc" \
    REF_CONF_DIR="/azerothcore/env/ref/etc" \
    LOGS_DIR="/azerothcore/env/dist/logs" \
    TEMP_DIR="/azerothcore/env/dist/temp" \
    DATA_DIR="/azerothcore/env/dist/data" \
    EXTERNAL_INPUT_DIR="/azerothcore/external" \
    AC_DB_HOST="database" \
    AC_DB_PORT="3306" \
    AC_DB_USER="acore" \
    AC_DB_PASSWORD="acore" \
    AC_AUTH_DATABASE="acore_auth" \
    AC_WORLD_DATABASE="acore_world" \
    AC_CHARACTER_DATABASE="acore_characters" \
    AC_REALM_ID="1" \
    AC_REALM_NAME="AzerothCore" \
    AC_REALM_ADDRESS="127.0.0.1" \
    AC_REALM_LOCAL_ADDRESS="127.0.0.1" \
    AC_REALM_LOCAL_SUBNET_MASK="255.255.255.0" \
    AC_REALM_PORT="8085" \
    AC_FORCE_DATA_IMPORT="0"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash tzdata ca-certificates unzip gettext-base \
        default-mysql-client libmysqlclient21 libreadline8 \
    && ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /azerothcore

RUN mkdir -p \
        /azerothcore/env/dist/bin \
        /azerothcore/env/dist/etc/modules \
        /azerothcore/env/dist/logs \
        /azerothcore/env/dist/temp \
        /azerothcore/env/dist/data \
        /azerothcore/external

COPY --from=build /azerothcore/env/dist/etc/ /azerothcore/env/ref/etc/
COPY --from=build /azerothcore/env/dist/bin/authserver /azerothcore/env/dist/bin/authserver
COPY --from=build /azerothcore/env/dist/bin/worldserver /azerothcore/env/dist/bin/worldserver
COPY data /azerothcore/data
COPY modules /azerothcore/modules

COPY --chmod=755 apps/docker/entrypoint.sh /usr/local/bin/ac-entrypoint.sh

VOLUME ["/azerothcore/env/dist/etc", "/azerothcore/env/dist/logs", "/azerothcore/env/dist/temp", "/azerothcore/env/dist/data"]

ENTRYPOINT ["/usr/local/bin/ac-entrypoint.sh"]

FROM runtime-base AS authserver

LABEL description="AzerothCore authserver runtime image"

ENV ACORE_COMPONENT="authserver"

CMD ["authserver"]

FROM runtime-base AS worldserver

LABEL description="AzerothCore worldserver runtime image"

ENV ACORE_COMPONENT="worldserver"

CMD ["worldserver"]
