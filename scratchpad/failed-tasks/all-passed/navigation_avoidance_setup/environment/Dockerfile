FROM ubuntu:24.04

# Install always required apt packages, Godot 4 dependencies, and unzip
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep unzip \
        libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1-mesa-dri libgl1 libglx0 libasound2t64 libfontconfig1 libxrender1 libdbus-1-3 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf pytest-xprocess && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Godot 4.3-stable standard Linux binary
RUN wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && \
    unzip Godot_v4.3-stable_linux.x86_64.zip && \
    mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm Godot_v4.3-stable_linux.x86_64.zip

# Set up user directory
RUN mkdir -p /home/user && chmod 0755 /home/user

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4.3-stable headless environment for testing 2D navigation and dynamic obstacle avoidance."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - extra apt packages: unzip, libxcursor1, libxinerama1, libxrandr2, libxi6, libgl1-mesa-dri, libgl1, libglx0, libasound2t64, libfontconfig1, libxrender1, libdbus-1-3 (for Godot 4 headless dependencies)
#   - extra pip3 packages: pytest-xprocess (for managing background Godot processes in tests)
#   - Godot 4.3-stable installed in /usr/local/bin/godot
#   - /home/user: user home directory
