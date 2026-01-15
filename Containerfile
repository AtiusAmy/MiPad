# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /
# Base Image
FROM quay.io/pocketblue/xiaomi-nabu-gnome-mobile:43
COPY system_files /

# Copy Homebrew files from the brew image
# And enable
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer


## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10
# `yq` be used to pass BlueBuild modules configuration written in yaml
COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq

RUN \
  # add in the module source code
  --mount=type=bind,from=ghcr.io/blue-build/modules:latest,src=/modules,dst=/tmp/modules,rw \
  # add in the script that sets up the module run environment
  --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:latest,src=/scripts/,dst=/tmp/scripts/ \
  
# run the module
config=$'\
type: gnome-extensions \n\
install: \n\
    - Caffeine # https://extensions.gnome.org/extension/517/caffeine/ \n\
    - AppIndicator and KStatusNotifierItem Support # https://extensions.gnome.org/extension/615/appindicator-support/ \n\
    - Blur my Shell # https://extensions.gnome.org/extension/3193/blur-my-shell/ \n\
    - Battery Health Charging # https://extensions.gnome.org/extension/5724/battery-health-charging/ \n\
    - Screen Rotate # https://extensions.gnome.org/extension/5389/screen-rotate/ \n\
' && \
/tmp/scripts/run_module.sh "$(echo "$config" | yq eval '.type')" "$(echo "$config" | yq eval -o=j -I=0)"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
### LINTING
## Verify final image and contents are correct.
#RUN bootc container lint
