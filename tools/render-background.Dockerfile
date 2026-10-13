FROM python:3.14-slim
RUN apt-get update && apt-get install -y --no-install-recommends xvfb xauth libvulkan1 mesa-vulkan-drivers libgl1-mesa-dri libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2 libpulse0 ca-certificates wget unzip && rm -rf /var/lib/apt/lists/*
COPY godot.zip /tmp/godot.zip
RUN unzip /tmp/godot.zip -d /opt && mv /opt/Godot_v4.5-stable_linux.arm64 /opt/godot && chmod +x /opt/godot && rm /tmp/godot.zip
ENV LIBGL_ALWAYS_SOFTWARE=1 GODOT_SILENCE_ROOT_WARNING=1
WORKDIR /project
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1 libxkbcommon0 && rm -rf /var/lib/apt/lists/*
