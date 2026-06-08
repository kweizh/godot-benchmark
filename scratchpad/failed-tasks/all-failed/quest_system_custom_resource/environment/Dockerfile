FROM ubuntu:24.04

# Install required apt packages, Python tooling, and Godot 4 headless binary.
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep \
        unzip libfontconfig1 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libglu1-mesa && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --break-system-packages pytest-json-ctrf && \
    curl -fsSL -o /tmp/godot.zip \
        https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && \
    unzip -q /tmp/godot.zip -d /opt/godot && \
    mv /opt/godot/Godot_v4.3-stable_linux.x86_64 /opt/godot/godot && \
    chmod +x /opt/godot/godot && \
    ln -s /opt/godot/godot /usr/local/bin/godot && \
    rm /tmp/godot.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the user home directory and the empty Godot project skeleton.
RUN mkdir -p /home/user && chmod 0755 /home/user && \
    mkdir -p /home/user/quest_project && \
    mkdir -p /home/user/quest_project/scripts && \
    mkdir -p /home/user/quest_project/autoloads && \
    mkdir -p /home/user/quest_project/resources/quests

# A minimal project.godot so that headless Godot recognises the directory as a
# project. The executor is expected to extend this file (e.g. to register the
# QuestManager autoload).
RUN cat >/home/user/quest_project/project.godot <<'EOF'
; Engine configuration file.
;
; Initial project skeleton for the quest_system_custom_resource Harbor task.

config_version=5

[application]

config/name="quest_project"
config/features=PackedStringArray("4.3")
EOF

# Pre-create an .gdignore in the verification staging dir so that the executor's
# project does not pick up stale files between runs. The verifier replaces this
# at test time.
RUN touch /home/user/quest_project/.gdignore_placeholder && rm /home/user/quest_project/.gdignore_placeholder

# Ensure the project can be imported headlessly without an interactive editor
# session. This generates the .godot/ cache so subsequent runs are fast and
# resource scripts created by the executor are discovered automatically.
RUN godot --headless --path /home/user/quest_project --import || true

LABEL Author="generate-harbor-tasks"
LABEL Description="Godot 4.3 headless environment with an empty quest_project skeleton at /home/user/quest_project for the quest_system_custom_resource task."

CMD ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]

# Container contents:
#   - always required apt packages: curl wget ca-certificates git python3 python3-pip python3-pytest bash ripgrep
#   - always required pip3 packages: pytest-json-ctrf
#   - Godot Engine 4.3 stable (Linux x86_64) installed at /opt/godot/godot and linked into /usr/local/bin/godot
#   - /home/user/quest_project: empty Godot 4 project skeleton with scripts/, autoloads/, resources/quests/
#   - /home/user/quest_project/project.godot: minimal project file (executor will extend with [autoload])
