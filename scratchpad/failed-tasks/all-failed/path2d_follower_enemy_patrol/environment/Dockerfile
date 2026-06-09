FROM ubuntu:24.04

# Base toolchain + Godot 4 runtime deps. Godot headless still pulls in a
# couple of X/GL libraries because the binary is linked against them; libfontconfig
# and libxi are required for headless project import on Linux x86_64 builds.
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep \
        unzip \
        libfontconfig1 libfreetype6 libxi6 libxcursor1 libxrandr2 libxinerama1 \
        libxext6 libx11-6 libxrender1 libgl1 libasound2t64 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Godot 4 headless from the official GitHub release. We pin to a known
# stable version so behavior is reproducible across builds.
ENV GODOT_VERSION=4.3-stable
RUN cd /tmp && \
    wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O godot.zip && \
    unzip -q godot.zip && \
    mv "Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm -f godot.zip && \
    /usr/local/bin/godot --headless --version

RUN mkdir -p /home/user && chmod 0755 /home/user

# Scaffold the empty Godot project the executor will work in.
RUN mkdir -p /home/user/myproject/scenes /home/user/myproject/scripts /home/user/myproject/data && \
    cat >/home/user/myproject/project.godot <<'EOF'
; Engine configuration for Path2D enemy patrol task.

config_version=5

[application]

config/name="Path2D Patrol"
config/features=PackedStringArray("4.3")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

# Initial waypoints fixture. The executor may change this if their solution
# depends on a specific scaffold, but the schema must remain
# {"waypoints": [[x, y], ...]} with at least 2 entries.
RUN cat >/home/user/myproject/data/waypoints.json <<'EOF'
{
  "waypoints": [[0, 0], [300, 0], [300, 300], [0, 300]]
}
EOF

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4 headless environment scaffolding a Path2D + PathFollow2D patrol task at /home/user/myproject."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - unzip + Godot 4 runtime libraries (libfontconfig1, libfreetype6, libxi6, libxcursor1, libxrandr2, libxinerama1, libxext6, libx11-6, libxrender1, libgl1, libasound2t64)
#   - Godot 4.3 stable headless binary at /usr/local/bin/godot
#   - /home/user/myproject: empty Godot project scaffold with project.godot, scenes/, scripts/, data/waypoints.json
