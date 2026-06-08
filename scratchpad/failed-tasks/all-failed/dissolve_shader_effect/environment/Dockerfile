FROM ubuntu:24.04

# Install base dependencies and system libraries for headless Godot and Python/pytest
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep unzip \
        libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2t64 libgl1-mesa-dri libgl1 libglx0 libxrender1 libxext6 \
        fontconfig && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf pytest-xprocess && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Godot 4.3 Stable
RUN wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -O /tmp/godot.zip && \
    unzip -q /tmp/godot.zip -d /usr/local/bin && \
    rm /tmp/godot.zip && \
    mv /usr/local/bin/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot

# Set up user and project directory
RUN mkdir -p /home/user/godot-benchmark

# Create initial project.godot file
RUN cat >/home/user/godot-benchmark/project.godot <<'EOF'
; Engine configuration file.
config_version=5

[application]
config/name="Godot Benchmark"
config/features=PackedStringArray("4.3", "Forward Plus")
EOF

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4.3 headless environment with Python and pytest-xprocess for dissolve shader effect evaluation."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - Ubuntu 24.04 base
#   - Python 3 and pytest
#   - Godot 4.3 stable installed at /usr/local/bin/godot
#   - Headless Godot dependencies (X11, GL, Sound, Fontconfig)
#   - /home/user/godot-benchmark with a valid project.godot file
