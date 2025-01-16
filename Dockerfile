# change to another nvidia cuda image base if needed
# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda/tags
FROM nvcr.io/nvidia/cuda:12.6.3-base-ubuntu24.04
# Install system dependencies
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --reinstall nano wget curl gpg git libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev sqlite3 && \
    apt-get autoclean && apt-get clean && rm -rf /var/lib/apt/lists/*
# Install pixi using the standalone installer
RUN curl -fsSL https://pixi.sh/install.sh | bash
# Ensure pixi is added to PATH
ENV PATH="/root/.pixi/bin:$PATH"
# Setup workspace and examples
WORKDIR /root
RUN git clone https://github.com/opengeos/segment-geospatial.git && \
    mkdir workspace && \
    mv /root/segment-geospatial/docs/examples /root/workspace/examples && \
    rm -fr /root/segment-geospatial
# Setup pixi environment with python 3.12.7
WORKDIR /root/workspace
RUN pixi init && pixi add "python=3.12.7"
# Pin to python 3.12.7
RUN printf '[tool.pixi]\nrequires-python = "==3.12.7"\n\n' > pyproject.toml
# Configure additional PyPI index URL for PyTorch
RUN printf '[pypi-options]\nextra-index-urls = ["https://download.pytorch.org/whl/cu124"]' >> pyproject.toml
# Add GDAL to pixi env
RUN pixi add gdal
# Add SQLite
RUN pixi add sqlite
# Add pip dependencies for installation in pixi env
RUN pixi add --pypi torch torchvision && \
    pixi add --pypi groundingdino-py segment-anything-fast jupyter jupyter-server-proxy && \
    pixi add --pypi segment-geospatial
# Cleaning up caches
RUN pixi clean cache -y && \
    find /root/.cache -mindepth 1 -delete
# Set environment variables
ARG LOCALTILESERVER_CLIENT_PREFIX='proxy/{port}'
ENV LOCALTILESERVER_CLIENT_PREFIX=$LOCALTILESERVER_CLIENT_PREFIX
# Activate jupyter extension and its jupyter server proxy config
WORKDIR /root/workspace
RUN pixi run jupyter server extension enable --sys-prefix jupyter_server_proxy

EXPOSE 8888
CMD ["pixi", "run", "jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
