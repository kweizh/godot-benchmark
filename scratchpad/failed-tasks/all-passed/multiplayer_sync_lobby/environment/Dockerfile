FROM ubuntu:24.04

# Install system dependencies, python packages, and Godot 4.3-stable
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep unzip \
        libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1-mesa-dri libgl1 libglx0 libasound2t64 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf pytest-xprocess && \
    wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && \
    unzip Godot_v4.3-stable_linux.x86_64.zip && \
    mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm Godot_v4.3-stable_linux.x86_64.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up user directory and project folder
RUN mkdir -p /home/user/godot-benchmark && chmod 0755 /home/user/godot-benchmark

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4.3-stable environment for multiplayer synchronization lobby task."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot 4.3-stable binary installed globally at /usr/local/bin/godot
#   - Godot dependencies: libxcursor1 libxinerama1 libxrandr1 libxi1 libgl1-mesa-dri libgl1-mesa-glx libasound2t64
#   - pip3 packages: pytest-xprocess (for managing background Godot processes in tests)
#   - /home/user/godot-benchmark: target project directory
