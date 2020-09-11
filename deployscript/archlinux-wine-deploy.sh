#!/bin/bash
P_URL="https://www.playonlinux.com/wine/binaries/phoenicis/staging-linux-amd64/PlayOnLinux-wine-5.11-staging-linux-amd64.tar.gz"
P_NAME="$(echo ${P_URL} | cut -d/ -f4)"
P_MVERSION="$(echo ${P_URL} | cut -d/ -f7)"
P_FILENAME="$(echo ${P_URL} | cut -d/ -f8)"
P_CSOURCE="$(echo ${P_FILENAME} | cut -d- -f1)"
P_VERSION="$(echo ${P_FILENAME} | cut -d- -f3)"
WINE_WORKDIR="wineversion"
PKG_WORKDIR="pkg_work"

#=========================
die() { echo >&2 "$*"; exit 1; };
#=========================

#Initializing the keyring requires entropy
pacman-key --init

# Enable Multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Configure for compilation:
#sed -i '/^BUILDENV/s/\!ccache/ccache/' /etc/makepkg.conf
sed -i '/#MAKEFLAGS=/c MAKEFLAGS="-j2"' /etc/makepkg.conf
#sed -i '/^COMPRESSXZ/s/\xz/xz -T 2/' /etc/makepkg.conf
#sed -i "s/^PKGEXT='.pkg.tar.gz'/PKGEXT='.pkg.tar.xz'/" /etc/makepkg.conf
#sed -i '$a   CFLAGS="$CFLAGS -w"'   /etc/makepkg.conf
#sed -i '$a CXXFLAGS="$CXXFLAGS -w"' /etc/makepkg.conf
sed -i 's/^CFLAGS\s*=.*/CFLAGS="-mtune=nehalem -O2 -pipe -ftree-vectorize -fno-stack-protector"/' /etc/makepkg.conf
sed -i 's/^CXXFLAGS\s*=.*/CXXFLAGS="-mtune=nehalem -O2 -pipe -ftree-vectorize -fno-stack-protector"/' /etc/makepkg.conf
#sed -i 's/^LDFLAGS\s*=.*/LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"/' /etc/makepkg.conf
sed -i 's/^#PACKAGER\s*=.*/PACKAGER="DanielDevBR"/' /etc/makepkg.conf
sed -i 's/^PKGEXT\s*=.*/PKGEXT=".pkg.tar"/' /etc/makepkg.conf
sed -i 's/^SRCEXT\s*=.*/SRCEXT=".src.tar"/' /etc/makepkg.conf

# Add more repo:
echo "" >> /etc/pacman.conf

# https://github.com/archlinuxcn/repo
echo "[archlinuxcn]" >> /etc/pacman.conf
#echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "SigLevel = Never" >> /etc/pacman.conf
echo "Server = https://repo.archlinuxcn.org/\$arch" >> /etc/pacman.conf
echo "" >> /etc/pacman.conf

# https://lonewolf.pedrohlc.com/chaotic-aur/
echo "[chaotic-aur]" >> /etc/pacman.conf
#echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "SigLevel = Never" >> /etc/pacman.conf
echo "Server = http://lonewolf-builder.duckdns.org/\$repo/x86_64" >> /etc/pacman.conf
echo "Server = http://chaotic.bangl.de/\$repo/x86_64" >> /etc/pacman.conf
echo "Server = https://repo.kitsuna.net/x86_64" >> /etc/pacman.conf
echo "" >> /etc/pacman.conf
#pacman-key --keyserver keys.mozilla.org -r 3056513887B78AEB
#pacman-key --lsign-key 3056513887B78AEB
#sudo pacman-key --keyserver hkp://p80.pool.sks-keyservers.net:80 -r 3056513887B78AEB
#sudo pacman-key --lsign-key 3056513887B78AEB

# workaround one bug: https://bugzilla.redhat.com/show_bug.cgi?id=1773148
echo "Set disable_coredump false" >> /etc/sudo.conf

echo "DEBUG: updating pacmam keys"
pacman -Syy --noconfirm && pacman --noconfirm -S archlinuxcn-keyring

echo "DEBUG: pacmam sync"
pacman -Syy --noconfirm

echo "DEBUG: pacmam updating system"
pacman -Syu --noconfirm

pacman -S --noconfirm wget git tar grep sed zstd xz bzip2
#===========================================================================================

mkdir "${WINE_WORKDIR}"
mkdir "${PKG_WORKDIR}"

# Get Wine
wget -nv -c ${P_URL}
tar xf ${P_FILENAME} -C "${WINE_WORKDIR}"/

# re-make for 64bits multilib:
wget -c https://github.com/ferion11/libsutil/releases/download/wine_hook_v0.9/wine_wow64_hooks.tar.gz
tar xf wine_wow64_hooks.tar.gz -C src/
#wget -nv -c https://github.com/ferion11/libsutil/releases/download/wine_hook_v0.9/libhookexecv.so
#wget -nv -c https://github.com/ferion11/libsutil/releases/download/wine_hook_v0.9/wine-preloader_hook
#mv libhookexecv.so src/
#mv wine-preloader_hook src/
# compile & strip libhookexecv wine-preloader_hook
#gcc -shared -fPIC -m32 -ldl src/libhookexecv.c -o src/libhookexecv.so
#gcc -std=c99 -m32 -static src/preloaderhook.c -o src/wine-preloader_hook
#strip src/libhookexecv.so src/wine-preloader_hook
#chmod +x src/wine-preloader_hook
#===========================================================================================

cd "${WINE_WORKDIR}" || die "ERROR: Directory don't exist: ${WINE_WORKDIR}"

# Add a dependency library:
dependencys="$(pactree -s -u wine | xargs)"
deplist32="lib32-alsa-lib lib32-alsa-plugins lib32-faudio lib32-fontconfig lib32-freetype2 lib32-gcc-libs lib32-gettext lib32-giflib lib32-glu lib32-gnutls lib32-gst-plugins-base lib32-lcms2 lib32-libjpeg-turbo lib32-libjpeg6-turbo lib32-libldap lib32-libpcap lib32-libpng lib32-libpng12 lib32-libsm lib32-libxcomposite lib32-libxcursor lib32-libxdamage lib32-libxi lib32-libxml2 lib32-libxmu lib32-libxrandr lib32-libxslt lib32-libxxf86vm lib32-mesa lib32-mesa-libgl lib32-mpg123 lib32-ncurses lib32-openal lib32-sdl2 lib32-v4l-utils lib32-libdrm lib32-libva lib32-krb5 lib32-flac lib32-gst-plugins-good lib32-libcups lib32-libwebp lib32-libvpx lib32-libvpx1.3 lib32-portaudio lib32-sdl lib32-sdl2_image lib32-sdl2_mixer lib32-sdl2_ttf lib32-sdl_image lib32-sdl_mixer lib32-sdl_ttf lib32-smpeg lib32-speex lib32-speexdsp lib32-twolame lib32-ladspa lib32-libao lib32-libvdpau lib32-libpulse lib32-libcanberra-pulse lib32-libcanberra-gstreamer lib32-glew lib32-mesa-demos lib32-jansson lib32-libxinerama lib32-atk lib32-vulkan-icd-loader lib32-vulkan-intel lib32-vulkan-radeon lib32-vkd3d lib32-aom lib32-gsm lib32-lame lib32-libass lib32-libbluray lib32-dav1d lib32-libomxil-bellagio lib32-x264 lib32-x265 lib32-xvidcore lib32-opencore-amr lib32-openjpeg2 lib32-ncurses5-compat-libs lib32-ffmpeg"
deplist64="glibc gcc-libs libutil-linux systemd-libs cryptsetup gnutls gnupg libcap-ng util-linux systemd"

mkdir cache

pacman -Scc --noconfirm
pacman -Syw --noconfirm --cachedir cache $deplist64 $deplist32 $dependencys || die "ERROR: Some packages not found!!!"

# Remove non lib32 pkgs before extracting
#echo "All files in ./cache: $(ls ./cache)"
echo "DEBUG: clean some packages"
rm -rf ./cache/lib32-clang*
rm -rf ./cache/lib32-nvidia-cg-toolkit*
rm -rf ./cache/lib32-ocl-icd*
rm -rf ./cache/lib32-opencl-mesa*

rm -rf ./cache/clang*
rm -rf ./cache/nvidia-cg-toolkit*
rm -rf ./cache/ocl-icd*
rm -rf ./cache/opencl-mesa*
echo "All files in ./cache: $(ls ./cache)"

#=================================================

# extracting *tar.xz...
find ./cache -name '*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;

# extracting *tar.zst...
find ./cache -name '*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;
#----------------------------------------------

# WINE_WORKDIR cleanup
rm -rf cache; rm -rf include; rm usr/lib32/{*.a,*.o}; rm -rf usr/lib32/pkgconfig; rm -rf share/man; rm -rf usr/include; rm -rf usr/share/{applications,doc,emacs,gtk-doc,java,licenses,man,info,pkgconfig}; rm usr/lib32/locale
rm -rf boot; rm -rf dev; rm -rf home; rm -rf mnt; rm -rf opt; rm -rf proc; rm -rf root; rm sbin; rm -rf srv; rm -rf sys; rm -rf tmp; rm -rf var
rm -rf usr/src; rm -rf usr/share; rm usr/sbin; rm -rf usr/local; rm usr/lib/{*.a,*.o}
#===========================================================================================

## fix broken link libglx_indirect and others
#rm usr/lib32/libGLX_indirect.so.0
#ln -s libGLX_mesa.so.0 libGLX_indirect.so.0
#mv -n libGLX_indirect.so.0 usr/lib32
##--------

#rm usr/lib32/libkeyutils.so
#ln -s libkeyutils.so.1 libkeyutils.so
#mv -n libkeyutils.so usr/lib32
##--------

## workaround some of "wine --check-libs" wrong versions
#ln -s libpcap.so libpcap.so.0.8
#mv -n libpcap.so.0.8 usr/lib32

#ln -s libva.so libva.so.1
#ln -s libva-drm.so libva-drm.so.1
#ln -s libva-x11.so libva-x11.so.1
#mv -n libva.so.1 usr/lib32
#mv -n libva-drm.so.1 usr/lib32
#mv -n libva-x11.so.1 usr/lib32
#===========================================================================================

# Disable PulseAudio
rm etc/asound.conf; rm -rf etc/modprobe.d/alsa.conf; rm -rf etc/pulse

# Disable winemenubuilder
sed -i 's/winemenubuilder.exe -a -r/winemenubuilder.exe -r/g' share/wine/wine.inf

# Disable FileOpenAssociations
sed -i 's|    LicenseInformation|    LicenseInformation,\\\n    FileOpenAssociations|g;$a \\n[FileOpenAssociations]\nHKCU,Software\\Wine\\FileOpenAssociations,"Enable",,"N"' share/wine/wine.inf
#===========================================================================================

# appimage
cd ..

wget -nv -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O  appimagetool.AppImage
chmod +x appimagetool.AppImage

chmod +x AppRun

cp src/{libhookexecv32.so,libhookexecv64.so,wine-preloader_hook,wine64-preloader_hook} ${WINE_WORKDIR}/bin
rm src/{libhookexecv32.so,libhookexecv64.so,wine-preloader_hook,wine64-preloader_hook}

cp AppRun ${WINE_WORKDIR}
cp resource/* ${WINE_WORKDIR}
#-----------------------------

./appimagetool.AppImage --appimage-extract

export ARCH=x86_64; squashfs-root/AppRun -v ${WINE_WORKDIR} -u 'gh-releases-zsync|ferion11|Wine_Appimage|continuous|${P_NAME}-${P_MVERSION}-fulldeps-v${P_VERSION}-${P_CSOURCE}-*arch*.AppImage.zsync' ${P_NAME}-${P_MVERSION}-fulldeps-v${P_VERSION}-${P_CSOURCE}-${ARCH}.AppImage

echo "Packing tar result file..."
rm -rf appimagetool.AppImage
tar cvf result.tar *.AppImage *.zsync
echo "* result.tar size: $(du -hs result.tar)"