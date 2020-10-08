#!/bin/bash -ex
mkdir -p "$HOME/.ccache"

chmod a+x ./.ci/scripts/linux-flatpak/docker.sh

docker run --env-file .ci/scripts/linux-flatpak/azure-ci.env --env-file .ci/scripts/linux-flatpak/azure-ci-flatpak.env -v $(pwd):/yuzu -v "$HOME/.ccache":/home/yuzu/.ccache -v "$HOME/.ssh":/home/yuzu/.ssh --privileged meirod/build-environments:linux-flatpak /bin/bash -ex /yuzu/.ci/scripts/linux-flatpak/docker.sh
