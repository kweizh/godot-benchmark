FROM ubuntu:24.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep \
        unzip xz-utils \
        libfontconfig1 libfreetype6 libx11-6 libxcursor1 libxi6 libxrandr2 \
        libxinerama1 libxrender1 libgl1 libglu1-mesa libasound2t64 libpulse0 \
        libdbus-1-3 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Godot Engine 4 (headless-capable Linux x86_64 build).
RUN mkdir -p /opt/godot && \
    cd /tmp && \
    curl -fsSL -o godot.zip \
        https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && \
    unzip -q godot.zip -d /opt/godot && \
    mv /opt/godot/Godot_v4.3-stable_linux.x86_64 /opt/godot/godot && \
    chmod +x /opt/godot/godot && \
    ln -s /opt/godot/godot /usr/local/bin/godot && \
    rm -f /tmp/godot.zip

RUN mkdir -p /home/user && chmod 0755 /home/user

# Initial Godot 4 project skeleton the executor will build the minimap inside.
RUN mkdir -p /home/user/myproject/scenes /home/user/myproject/scripts && \
    cat >/home/user/myproject/project.godot <<'EOF'
; Engine configuration file.
; Generated for the subviewport_minimap Harbor task.

config_version=5

[application]

config/name="SubViewportMinimap"
config/features=PackedStringArray("4.3", "Forward Plus")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

# Warm up Godot's first-run import cache so headless runs do not have to do it
# every time, and surface any binary issues at build time.
RUN godot --headless --version

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4 headless environment for the subviewport_minimap task with a starter Godot project at /home/user/myproject."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot Engine 4.3 stable Linux x86_64 binary at /opt/godot/godot, symlinked as `godot`
#   - /home/user/myproject: starter Godot 4 project (project.godot, scenes/, scripts/) for the executor to extend
