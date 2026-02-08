# Supported images are based (or their parents are) on the `ubuntu` releases 20.04, 22.04, 24.04
FROM docker-registry.qualcomm.com/library/nvidia/cuda:12.0.0-cudnn8-devel-ubuntu22.04

ADD "https://gitlab.qualcomm.com/api/v4/projects/13064/repository/files/configure_morpheus_image.sh/raw?ref=v4.2.0" /tmp/configure_morpheus_image.sh

RUN bash /tmp/configure_morpheus_image.sh

SHELL ["/bin/bash", "--login", "-c"]

# As of Ubuntu 24, it is not possible to update the system pip by running `python3 -m pip --upgrade install pip`, which often is a prerequisite for new pip packages.
# Instead, we install pip directly from pypa.io. Then, the scary-looking `PIP_BREAK_SYSTEM_PACKAGES` is required.
# Afterwards, it's not an issue if a system pip gets installed (as a dependency, say) - pypa.io's pip takes precedence on the PATH and within Python.

ENV PATH=${PATH}:/pkg/icetools/bin \
    PIP_BREAK_SYSTEM_PACKAGES=1

# Appending DistillT5 installation-site to PYTHONPATH
ENV PYTHONPATH=${DISTILLT5_INSTALL_SITE}:${PYTHONPATH}

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install --yes --no-install-recommends \
        acl \
        build-essential  `# required for installing detectron2` \
        git \
        less \
        nano \
        vim \
        python3-venv \
        python-is-python3 \
        python3 \
        python3-dev  `# required for installing detectron2` \
        sudo \
        net-tools \
        pdsh \
        wget \
        ffmpeg \
        && \
    setfacl -m g::rwx,o::rwx -d -m g::rwx,o::rwx $(python3 -c 'from sysconfig import get_path; print(get_path("purelib"), get_path("platlib"), get_path("scripts"))') && \
    rm -rf /var/lib/apt/lists/*
 
# For Ubuntu 20.04, pip installation yields `ModuleNotFoundError: No module named 'distutils.cmd'`. Install `python3-distutils` via `apt` to fix this.
RUN curl https://bootstrap.pypa.io/get-pip.py | python3

COPY requirements.txt requirements.txt
COPY requirements_video_vae.txt requirements_video_vae.txt
    

RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir --upgrade --index-url https://download.pytorch.org/whl/cu121 torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 && \
    python3 -m pip install --no-cache-dir --upgrade psutil


RUN python3 -m pip install --no-cache-dir --no-build-isolation --upgrade pip && \
    python3 -m pip install --no-cache-dir --no-build-isolation --upgrade --requirement requirements.txt --extra-index-url  https://download.pytorch.org/whl/cu121 && \
    python3 -m pip install --no-cache-dir --no-build-isolation --upgrade --requirement requirements_video_vae.txt --extra-index-url  https://download.pytorch.org/whl/cu121

# Installs DiffSynth-Studio into the docker image
RUN --mount=type=bind,rw,target=/docker-ctx python3 -m pip install --no-cache-dir --no-dependencies -e /docker-ctx
