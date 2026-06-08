FROM ubuntu:24.04

ENV GODOT_VERSION=4.3-stable

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep \
        unzip xz-utils libfontconfig1 libfreetype6 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" && \
    unzip -q /tmp/godot.zip -d /opt/godot && \
    mv /opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /opt/godot/godot && \
    chmod +x /opt/godot/godot && \
    ln -s /opt/godot/godot /usr/local/bin/godot && \
    rm -f /tmp/godot.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/user && chmod 0755 /home/user
RUN mkdir -p /home/user/myproject

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot Engine 4.3 headless environment with an empty project scaffold at /home/user/myproject for the audio_bus_dynamic_mixer task."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - extra apt packages: unzip xz-utils (used to extract the Godot release archive)
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot Engine 4.3 stable binary installed at /opt/godot/godot and symlinked to /usr/local/bin/godot
#   - /home/user/myproject: empty project scaffold for the executor to populate
