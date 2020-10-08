#!/bin/bash -ex
# This script generates the appdata.xml and org.yuzu.$REPO_NAME.json files
# needed to define application metadata and build yuzu

# Converts "yuzu-emu/yuzu-release" to "yuzu-release"
REPO_NAME=$(echo $AZURE_REPO_SLUG | cut -d'/' -f 2)
# Converts "yuzu-release" to "yuzu Release"
REPO_NAME_FRIENDLY=$(echo $REPO_NAME | sed -e 's/-/ /g' -e 's/\b\(.\)/\u\1/g')

# Generate the correct appdata.xml for the version of yuzu we're building
cat > /tmp/appdata.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<application>
  <id type="desktop">org.yuzu.$REPO_NAME.desktop</id>
  <name>$REPO_NAME_FRIENDLY</name>
  <summary>Nintendo Switch emulator</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-2.0</project_license>
  <description>
    <p>yuzu is an experimental open-source emulator for the Nintendo Switch from the creators of Citra.</p>
    <p>It is written in C++ with portability in mind, with builds actively maintained for Windows and Linux. The emulator is currently only useful for homebrew development and research purposes.</p>
    <p>yuzu only emulates a subset of Switch hardware and therefore is generally only useful for running/debugging homebrew applications. At this time, yuzu cannot play a majority of commercial games without major problems. yuzu can boot some commercial Switch games to varying degrees of success, but your experience may vary between games and for different combinations of host hardware.</p>
    <p>yuzu is licensed under the GPLv2 (or any later version). Refer to the license.txt file included.</p>
  </description>
  <url type="homepage">https://yuzu-emu.org/</url>
  <url type="donation">https://yuzu-emu.org/donate/</url>
  <url type="bugtracker">https://github.com/yuzu-emu/yuzu/issues</url>
  <url type="faq">https://yuzu-emu.org/wiki/faq/</url>
  <url type="help">https://yuzu-emu.org/wiki/home/</url>
  <screenshot>https://yuzu-emu.org/images/screenshots/001-Super%20Mario%20Odyssey.png</screenshot>
  <screenshot>https://yuzu-emu.org/images/screenshots/004-Super%20Mario%20Odyssey.png</screenshot>
  <screenshot>https://yuzu-emu.org/images/screenshots/019-Pokken%20Tournament.png</screenshot>
  <screenshot>https://yuzu-emu.org/images/screenshots/052-Pokemon%20Let%27s%20Go.png</screenshot>
  <categories>
    <category>Games</category>
    <category>Emulator</category>
  </categories>
</application>
EOF

cat > /tmp/yuzu-wrapper <<EOF
#!/bin/bash

# Discord only accepts activity updates from pids >= 10
for i in 1 2 3 .. 20
do
    # Spawn a new shell
    # This guarantees that a new process is created (unlike with potential bash internals like echo etc.)
    bash -c "true"
    sleep 0
done

# Symlink com.discordapp.Discord ipc pipes if they do not exist yet
for i in {0..9}; do
    test -S \$XDG_RUNTIME_DIR/app/com.discordapp.Discord/discord-ipc-\$i && ln -sf {\$XDG_RUNTIME_DIR/app/com.discordapp.Discord,\$XDG_RUNTIME_DIR}/discord-ipc-\$i;
done

yuzu \$@
EOF

# Generate the yuzu flatpak manifest
cat > /tmp/org.yuzu.$REPO_NAME.json <<EOF
{
    "app-id": "org.yuzu.$REPO_NAME",
    "runtime": "org.kde.Sdk",
    "runtime-version": "5.13",
    "sdk": "org.kde.Sdk",
    "command": "yuzu",
    "rename-desktop-file": "yuzu.desktop",
    "rename-icon": "yuzu",
    "rename-appdata-file": "org.yuzu.$REPO_NAME.appdata.xml",
    "build-options": {
        "build-args": [
            "--share=network"
        ],
        "env": {
            "AZURE_BRANCH": "$AZURE_BRANCH",
            "AZURE_BUILD_ID": "$AZURE_BUILD_ID",
            "AZURE_BUILD_NUMBER": "$AZURE_BUILD_NUMBER",
            "AZURE_COMMIT": "$AZURE_COMMIT",
            "AZURE_JOB_ID": "$AZURE_JOB_ID",
            "AZURE_REPO_SLUG": "$AZURE_REPO_SLUG",
            "AZURE_TAG": "$AZURE_TAG"
            /* Required for conan to work properly */
            "HOME": "/run/build/yuzu"
        }
    },
    "finish-args": [
        "--device=all",
        "--socket=x11",
        "--socket=pulseaudio",
        "--share=network",
        "--share=ipc",
        "--filesystem=xdg-config/yuzu:create",
        "--filesystem=xdg-data/yuzu:create",
        "--filesystem=host:ro",	
        "--filesystem=xdg-run/app/com.discordapp.Discord:create",
        "--filesystem=xdg-run/discord-ipc-0:rw",
        "--filesystem=xdg-run/discord-ipc-1:rw",
        "--filesystem=xdg-run/discord-ipc-2:rw",
        "--filesystem=xdg-run/discord-ipc-3:rw",
        "--filesystem=xdg-run/discord-ipc-4:rw",
        "--filesystem=xdg-run/discord-ipc-5:rw",
        "--filesystem=xdg-run/discord-ipc-6:rw",
        "--filesystem=xdg-run/discord-ipc-7:rw",
        "--filesystem=xdg-run/discord-ipc-8:rw",
        "--filesystem=xdg-run/discord-ipc-9:rw"
    ],
    "cleanup-commands": [
        "find ${FLATPAK_DEST}/bin ! -name 'yuzu*' -mindepth 1 -delete",
        "rm -r ${FLATPAK_DEST}/lib/*python*"
    ],
    "modules": [
        /* Flathub shared module */
        {
            "name": "python-2.7",
            "sources": [
                {
                    "type": "archive",
                    "url": "https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz",
                    "sha256": "b62c0e7937551d0cc02b8fd5cb0f544f9405bafc9a54d3808ed4594812edef43"
                }
            ],
            "config-opts": [
                "--enable-shared",
                "--with-ensurepip=yes",
                "--with-system-expat",
                "--with-system-ffi",
                "--enable-loadable-sqlite-extensions",
                "--with-dbmliborder=gdbm",
                "--enable-unicode=ucs4"
            ],
            "post-install": [
                /* Theres seem to be a permissions missmatch that causes the debug stripping to fail */
                "chmod 644 $FLATPAK_DEST/lib/libpython2.7.so.1.0"
            ],
            "cleanup": [
                "/bin/2to3*",
                "/bin/easy_install*",
                "/bin/idle*",
                "/bin/pydoc*",
                "/bin/python*-config",
                "/bin/pyvenv*",
                "/include",
                "/lib/pkgconfig",
                "/lib/python*/config",
                "/share",

                /* Test scripts */
                "/lib/python*/test",
                "/lib/python*/*/test",
                "/lib/python*/*/tests",
                "/lib/python*/lib-tk/test",
                "/lib/python*/lib-dynload/_*_test.*.so",
                "/lib/python*/lib-dynload/_test*.*.so",

                /* Unused modules */
                "/lib/python*/idlelib",
                "/lib/python*/tkinter*",
                "/lib/python*/turtle*",
                "/lib/python*/lib2to3*",
                
                /* Static library */
                "/lib/python2.7/config/libpython2.7.a"
            ]
        },
        /* Generated by flatpak-pip-generator */
        {
            "name": "python3-conan",
            "buildsystem": "simple",
            "build-commands": [
                "pip3 install --exists-action=i --no-index --find-links=\"file://${PWD}\" --prefix=${FLATPAK_DEST} \"conan\""
            ],
            "sources": [
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/bc/a9/01ffebfb562e4274b6487b4bb1ddec7ca55ec7510b22e4c51f14098443b8/chardet-3.0.4-py2.py3-none-any.whl",
                    "sha256": "fc323ffcaeaed0e0a02bf4d117757b98aed530d9ed4531e3e15460124c106691"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/08/51/6cf3a2b18ca35cbe4ad3c7538a7c3dc0cb24e71629fb16e729c137d06432/node_semver-0.6.1-py3-none-any.whl",
                    "sha256": "d4bf83873894591a0cbb6591910d96917fbadc9731e8e39e782d3a2fbc2b841e"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/46/19/c5ab91b1b05cfe63cccd5cfc971db9214c6dd6ced54e33c30d5af1d2bc43/packaging-20.4-py2.py3-none-any.whl",
                    "sha256": "998416ba6962ae7fbd6596850b80e17859a5753ba17c32284f67bfff33784181"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/5e/c4/6c4fe722df5343c33226f0b4e0bb042e4dc13483228b4718baf286f86d87/certifi-2020.6.20-py2.py3-none-any.whl",
                    "sha256": "8fc0819f1f30ba15bdb34cceffb9ef04d99f420f68eb75d901e9560b8749fc41"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/c9/dc/45cdef1b4d119eb96316b3117e6d5708a08029992b2fee2c143c7a0a5cc5/colorama-0.4.3-py2.py3-none-any.whl",
                    "sha256": "7d73d2a99753107a36ac6b455ee49046802e59d9d076ef8e47b61499fa29afff"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/9f/f0/a391d1463ebb1b233795cabfc0ef38d3db4442339de68f847026199e69d7/urllib3-1.25.10-py2.py3-none-any.whl",
                    "sha256": "e7983572181f5e1522d9c98453462384ee92a0be7fac5f1413a1e35c56cc0461"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/d7/72/49a7db1b245c13d0e38cfdc96c1adf6e3bd16a7a0dceb7b25faa6612353b/Pygments-2.7.1-py3-none-any.whl",
                    "sha256": "307543fe65c0947b126e83dd5a61bd8acbd84abec11f43caebaf5534cbc17998"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/25/b7/b3c4270a11414cb22c6352ebc7a83aaa3712043be29daa05018fd5a5c956/distro-1.5.0-py2.py3-none-any.whl",
                    "sha256": "df74eed763e18d10d0da624258524ae80486432cd17392d9c3d96f5e83cd2799"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/64/c2/b80047c7ac2478f9501676c988a5411ed5572f35d1beff9cae07d321512c/PyYAML-5.3.1.tar.gz",
                    "sha256": "b8eac752c5e14d3eca0e6dd9199cd627518cb5ec06add0de9d32baeee6fe645d"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/a7/f6/c437f320b4c998ef3f77b0823018078081cb615f88c7eed37a5523d70c0b/conan-1.30.0.tar.gz",
                    "sha256": "465e3fde8414e9abdaf6d8b8d2f501c88e6b4a79fcd4eb62541792746a2574e2"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/87/8b/6a9f14b5f781697e51259d81657e6048fd31a113229cf346880bb7545565/PyJWT-1.7.1-py2.py3-none-any.whl",
                    "sha256": "5c6eca3c2940464d106b99ba83b00c6add741c9becaec087fb7ccdefea71350e"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/a2/38/928ddce2273eaa564f6f50de919327bf3a00f091b5baba8dfa9460f3a8a8/idna-2.10-py2.py3-none-any.whl",
                    "sha256": "b97d804b1e9b523befed77c48dacec60e6dcb0b5391d57af6a65a312a90648c0"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/b9/2e/64db92e53b86efccfaea71321f597fa2e1b2bd3853d8ce658568f7a13094/MarkupSafe-1.1.1.tar.gz",
                    "sha256": "29872e92839765e546828bb7754a68c418d927cd064fd4708fab9fe9c8bb116b"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/30/9e/f663a2aa66a09d838042ae1a2c5659828bb9b41ea3a6efa20a20fd92b121/Jinja2-2.11.2-py2.py3-none-any.whl",
                    "sha256": "f0a4641d3cf955324a89c04f3d94663aa4d638abe8f733ecd3582848e1c37035"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/45/0b/38b06fd9b92dc2b68d58b75f900e97884c45bedd2ff83203d933cf5851c9/future-0.18.2.tar.gz",
                    "sha256": "b1bead90b70cf6ec3f0710ae53a525360fa360d306a86583adc6bf83a4db537d"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/45/1e/0c169c6a5381e241ba7404532c16a21d86ab872c9bed8bdcd4c423954103/requests-2.24.0-py2.py3-none-any.whl",
                    "sha256": "fe75cc94a9443b9246fc7049224f75604b113c36acb93f87b80ed42c44cbb898"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/b9/2a/d5084a8781398cea745c01237b95d9762c382697c63760a95cc6a814ad3a/deprecation-2.0.7-py2.py3-none-any.whl",
                    "sha256": "dc9b4f252b7aca8165ce2764a71da92a653b5ffbf7a389461d7a640f6536ecb2"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/e9/39/2bf3a1fd963e749cdbe5036a184eda8c37d8af25d1297d94b8b7aeec17c4/bottle-0.12.18-py3-none-any.whl",
                    "sha256": "43157254e88f32c6be16f8d9eb1f1d1472396a4e174ebd2bf62544854ecf37e7"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/3d/3c/fe974b4f835f83cc46966e04051f8708b7535bac28fbc0dcca1ee0c237b8/pluginbase-1.0.0.tar.gz",
                    "sha256": "497894df38d0db71e1a4fbbfaceb10c3ef49a3f95a0582e11b75f8adaa030005"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/ac/aa/063eca6a416f397bd99552c534c6d11d57f58f2e94c14780f3bbf818c4cf/monotonic-1.5-py2.py3-none-any.whl",
                    "sha256": "552a91f381532e33cbd07c6a2655a21908088962bb8fa7239ecbcc6ad1140cc7"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/c1/b2/ad3cd464101435fdf642d20e0e5e782b4edaef1affdf2adfc5c75660225b/patch-ng-1.17.4.tar.gz",
                    "sha256": "627abc5bd723c8b481e96849b9734b10065426224d4d22cd44137004ac0d4ace"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/ee/ff/48bde5c0f013094d729fe4b0316ba2a24774b3ff1c52d924a8a4cb04078a/six-1.15.0-py2.py3-none-any.whl",
                    "sha256": "8b74bedcbbbaca38ff6d7491d76f2b06b3592611af620f8426e82dddb04a5ced"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/12/cd/2dc00ab02b89727062697e0851b512664c851f77b4f272b74489d82d9d37/tqdm-4.50.1-py2.py3-none-any.whl",
                    "sha256": "5313148c57fcca7df562187903cf9cfa30fe1df2fe0641ea6ddb8ef9e841a137"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/18/bd/55eb2d6397b9c0e263af9d091ebdb756b15756029b3cededf6461481bc63/fasteners-0.15-py2.py3-none-any.whl",
                    "sha256": "007e4d2b2d4a10093f67e932e5166722d2eab83b77724156e92ad013c6226574"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/8a/bb/488841f56197b13700afd5658fc279a2025a39e22449b7cf29864669b15d/pyparsing-2.4.7-py2.py3-none-any.whl",
                    "sha256": "ef9d7589ef3c200abe66653d3f1ab1033c3c419ae9b9bdb1240a85b024efc88b"
                },
                {
                    "type": "file",
                    "url": "https://files.pythonhosted.org/packages/d4/70/d60450c3dd48ef87586924207ae8907090de0b306af2bce5d134d78615cb/python_dateutil-2.8.1-py2.py3-none-any.whl",
                    "sha256": "75bb3f31ea686f1197762692a9ee6a7550b59fc6ca3a1f4b5d7e32fb98e2da2a"
                }
            ]
        },
        {
            "name": "yuzu",
            "buildsystem": "cmake-ninja",
            "builddir": true,
            "config-opts": [
                "-DDISPLAY_VERSION=$1",
                "-DYUZU_USE_BUNDLED_UNICORN=ON",
                "-DYUZU_USE_QT_WEB_ENGINE=OFF",
                "-DCMAKE_BUILD_TYPE=Release",
                "-DYUZU_ENABLE_COMPATIBILITY_REPORTING=ON",
                "-DENABLE_COMPATIBILITY_LIST_DOWNLOAD=ON",
                "-DUSE_DISCORD_PRESENCE=ON",
                "-DENABLE_VULKAN=Yes"
            ],
            "cleanup": [
              "/bin/yuzu-cmd",
              "/share/man",
              "/share/pixmaps"
            ],
            "post-install": [
                "install -Dm644 ../appdata.xml /app/share/appdata/org.yuzu.$REPO_NAME.appdata.xml",
                "desktop-file-install --dir=/app/share/applications ../dist/yuzu.desktop",
                "install -Dm644 ../dist/yuzu.svg /app/share/icons/hicolor/scalable/apps/yuzu.svg",
                "sed -i 's/Name=yuzu/Name=$REPO_NAME_FRIENDLY/g' /app/share/applications/yuzu.desktop",
                "mv /app/share/mime/packages/yuzu.xml /app/share/mime/packages/org.yuzu.$REPO_NAME.xml",
                "sed 's/yuzu/org.yuzu.$REPO_NAME/g' -i /app/share/mime/packages/org.yuzu.$REPO_NAME.xml",
                'install -D ../yuzu-wrapper /app/bin/yuzu-wrapper',
                "desktop-file-edit --set-key=Exec --set-value='/app/bin/yuzu-wrapper %f' /app/share/applications/yuzu.desktop"
            ],
            "sources": [
                {
                    "type": "git",
                    "url": "https://github.com/yuzu-emu/$REPO_NAME.git",
                    "branch": "master",
                    "disable-shallow-clone": true
                },
                {
                    "type": "file",
                    "path": "/tmp/appdata.xml"
                },
                {
                    "type": "file",
                    "path": "/tmp/yuzu-wrapper"
                }
            ]
        }
    ]
}
EOF

