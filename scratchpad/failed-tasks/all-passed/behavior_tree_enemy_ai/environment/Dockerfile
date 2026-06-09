FROM ubuntu:24.04

ARG TARGETARCH
ENV GODOT_VERSION=4.3-stable

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep unzip \
        libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libgl1 libasound2t64 \
        libfontconfig1 libfreetype6 libpulse0 libudev1 libdbus-1-3 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH:-amd64}" in \
        arm64) GODOT_ARCH=arm64 ;; \
        amd64|"") GODOT_ARCH=x86_64 ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.${GODOT_ARCH}.zip" && \
    unzip /tmp/godot.zip -d /tmp/godot && \
    mv "/tmp/godot/Godot_v4.3-stable_linux.${GODOT_ARCH}" /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm -rf /tmp/godot /tmp/godot.zip

RUN mkdir -p /home/user && chmod 0755 /home/user

RUN mkdir -p /home/user/myproject && \
    cat >/home/user/myproject/project.godot <<'EOF'
; Engine configuration file for the behavior_tree_enemy_ai task.
; The executor must implement the BT library described in the task.

config_version=5

[application]

config/name="behavior_tree_enemy_ai"
config/features=PackedStringArray("4.3", "GDScript")

[debug]

gdscript/warnings/untyped_declaration=0
EOF

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4.3 headless environment for the behavior_tree_enemy_ai task."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot Engine 4.3 stable headless binary installed at /usr/local/bin/godot (arch picked from TARGETARCH)
#   - X11/audio shared libraries required by the Godot binary's dynamic linker
#   - /home/user/myproject: empty Godot 4 project scaffold with project.godot
