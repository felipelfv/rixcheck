FROM ubuntu:24.04

RUN apt update -y && apt install -y curl

# Install the Nix package manager (Determinate Systems installer)
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
  --extra-conf "sandbox = false" \
  --init none \
  --no-confirm

ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"
ENV user=root

# rstats-on-nix binary cache: download precompiled packages instead of building
RUN mkdir -p /root/.config/nix && \
    echo "substituters = https://cache.nixos.org https://rstats-on-nix.cachix.org" > /root/.config/nix/nix.conf && \
    echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= rstats-on-nix.cachix.org-1:vdiiVgocg6WeJrODIqdprZRUrhi1JzhBnXv7aWI6+F0=" >> /root/.config/nix/nix.conf

WORKDIR /project

# Bring in the whole research compendium, including the pinned default.nix
COPY . /project

# Build the exact, pinned environment from the committed default.nix
RUN nix-build

CMD nix-shell default.nix --run "{{RUN}}"
