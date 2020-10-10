#!/bin/bash -ex
mkdir -p "ccache"


chmod a+x ./.ci/scripts/linux-flatpak/docker.sh

# the UID for the container yuzu user is 1027
#sudo chown -R 1027 "$HOME/.ssh"
sudo chown -R 1027 "ccache"
sudo chown -R 1027 $(pwd)
docker run --env-file .ci/scripts/linux-flatpak/azure-ci.env --env-file .ci/scripts/linux-flatpak/azure-ci-flatpak.env -v $(pwd):/yuzu -v "ccache":/home/yuzu/ccache -v "$HOME/.ssh":/home/yuzu/.ssh --privileged meirod/build-environments:linux-flatpak /bin/bash -ex /yuzu/.ci/scripts/linux-flatpak/docker.sh
#sudo chown -R $UID "$HOME/.ssh"
sudo chown -R $UID "ccache"
sudo chown -R $UID $(pwd)
