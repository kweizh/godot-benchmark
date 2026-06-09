FROM ubuntu:24.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep \
        unzip xz-utils \
        libfontconfig1 libfreetype6 libx11-6 libxcursor1 libxinerama1 libxrandr2 \
        libxi6 libgl1 libasound2t64 libpulse0 libdbus-1-3 libstdc++6 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Godot Engine 4.3 (stable) headless-capable binary. The standard Linux
# build supports the `--headless` flag, so a separate headless distribution is
# not required.
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "x86_64" ]; then GODOT_ARCH="linux.x86_64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then GODOT_ARCH="linux.arm64"; \
    else echo "Unsupported architecture: $ARCH" >&2; exit 1; fi && \
    cd /tmp && \
    curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_${GODOT_ARCH}.zip" && \
    unzip -q /tmp/godot.zip -d /tmp/godot && \
    mv "/tmp/godot/Godot_v4.3-stable_${GODOT_ARCH}" /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm -rf /tmp/godot /tmp/godot.zip

RUN mkdir -p /home/user && chmod 0755 /home/user

# Scaffold a minimal Godot 4 project at /home/user/myproject and seed the level
# layout JSON. The executor must NOT need to recreate either of these files.
RUN mkdir -p /home/user/myproject/levels && \
    cat >/home/user/myproject/project.godot <<'EOF'
; Engine configuration file for the A* grid pathfinding evaluation task.

config_version=5

[application]

config/name="AStarGridPathfinder"
config/features=PackedStringArray("4.3")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

RUN cat >/home/user/myproject/levels/test_level.json <<'EOF'
{
  "size": [8, 8],
  "solid": [
    [3, 1],
    [3, 2],
    [3, 3],
    [3, 4],
    [3, 5],
    [3, 6]
  ],
  "weights": []
}
EOF

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot Engine 4.3 headless environment scaffolded for a grid-based A* pathfinding task with a pre-seeded JSON level layout."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot 4.3-stable binary installed at /usr/local/bin/godot (supports --headless)
#   - Supporting libraries needed by the Godot binary even in --headless mode
#   - /home/user/myproject/project.godot: pre-seeded Godot 4 project descriptor
#   - /home/user/myproject/levels/test_level.json: pre-seeded level layout used by the verifier
