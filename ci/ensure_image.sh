#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

. "${script_dir}/utils.sh"

# Deletes a tmp Dockerfile
clean_dockerfile() {
    rm -f "${script_dir}/Dockerfile"
}

# Determine a base image (Cuda based or not)
if [[ ${USE_CUDA} == 1 ]]; then
    log INFO "Cuda is ON"
    base_image="nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_MAJOR_VERSION}-devel-ubuntu${UBUNTU_VERSION}"
    jax_install="pip install --upgrade pip && pip install --upgrade \"jax[cuda${CUDA_MAJOR_VERSION}_local]\" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html"
    cuda_tag="cuda"
else
    log INFO "Cuda is OFF"
    base_image="ubuntu:${UBUNTU_VERSION}"
    jax_install="pip install --upgrade pip && pip install --upgrade \"jax[cpu]\""
    cuda_tag="cpu"
fi

log INFO "Building an image..."
cat > "${script_dir}/Dockerfile" <<EOF

FROM ${base_image}

WORKDIR /lsqmbdp
RUN mkdir ./shared_dir
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common curl&& \
    DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:deadsnakes/ppa && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt install -y git python3.10 python3-pip
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
RUN python3.10 -m pip install --upgrade pip
RUN python3.10 -m pip install numpy
RUN python3.10 -m pip install pytest
RUN python3.10 -m pip install -U mypy
RUN python3.10 -m pip install pylint
RUN python3.10 -m pip install chex
RUN python3.10 -m pip install termtables
RUN python3.10 -m pip install argparse
RUN python3.10 -m pip install h5py
RUN python3.10 -m pip install -U setuptools
RUN python3.10 -m pip install git+https://github.com/LuchnikovI/qgoptax/
RUN ${jax_install}
COPY ./src ./src
COPY ./ci/entrypoint.sh ./src/entrypoint.sh
RUN chmod +x ./src/entrypoint.sh
RUN chmod +x ./src/benchmarks.py
RUN chmod +x ./src/random_im.py
RUN chmod +x ./src/gen_samples.py
RUN chmod +x ./src/train_im.py

ENTRYPOINT [ "/lsqmbdp/src/entrypoint.sh" ]

EOF

if docker build -t luchnikovi/lsqmbdp.${cuda_tag}:latest -f - "${script_dir}/.." < "${script_dir}/Dockerfile";
then
    log INFO "Image has been built"
    clean_dockerfile  # TODO: better to use trap
else
    log ERROR "Failed to build an image"
    clean_dockerfile  # TODO: better to use trap
    exit 1
fi
