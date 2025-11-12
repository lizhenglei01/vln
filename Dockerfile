# ===========================================================
# 基础镜像：Python 3.9（官方）
# ===========================================================
FROM python:3.9-slim
SHELL ["/bin/bash", "-lc"]

# ===========================================================
# 更换为阿里云 Debian 软件源（兼容两种路径）
# ===========================================================
RUN if [ -f /etc/apt/sources.list ]; then \
        sed -i 's|http://deb.debian.org|https://mirrors.aliyun.com|g' /etc/apt/sources.list && \
        sed -i 's|http://security.debian.org|https://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list; \
    elif [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's|http://deb.debian.org|https://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources && \
        sed -i 's|http://security.debian.org|https://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && apt-get clean

# ===========================================================
# 安装系统依赖
# ===========================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 libglib2.0-0 wget bzip2 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ===========================================================
# 安装 Miniconda 到 /opt/conda
# ===========================================================
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    bash ~/miniconda.sh -b -p ${CONDA_DIR} && \
    rm ~/miniconda.sh && \
    ${CONDA_DIR}/bin/conda clean -afy
RUN ln -s ${CONDA_DIR}/bin/conda /usr/local/bin/conda || true
ENV PATH=${CONDA_DIR}/bin:$PATH

# ===========================================================
# 修复 ToS 错误：彻底移除 defaults，仅使用 conda-forge + aihabitat
# ===========================================================
RUN printf "channels:\n  - conda-forge\n  - aihabitat\nchannel_priority: strict\ndefault_channels: []\n" > /root/.condarc

# ===========================================================
# 创建 conda 环境（用 --override-channels 避开 defaults）
# ===========================================================
RUN ${CONDA_DIR}/bin/conda create -y -n vln -c conda-forge --override-channels python=3.9

# ===========================================================
# 安装 habitat-sim（CPU + withbullet），仍用 --override-channels
# ===========================================================
RUN ${CONDA_DIR}/bin/conda install -y -n vln -c conda-forge -c aihabitat --override-channels habitat-sim=0.3.1 withbullet && \
    ${CONDA_DIR}/bin/conda clean -afy

# ===========================================================
# 设置 PATH：后续命令默认使用 vln 环境
# ===========================================================
ENV PATH=${CONDA_DIR}/envs/vln/bin:${CONDA_DIR}/bin:$PATH

# ===========================================================
# 设置 pip 源为阿里云镜像（可选）
# ===========================================================
ENV PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple

WORKDIR /app

# ===========================================================
# 安装 Python 依赖（requirements_clean.txt 里不要含 habitat-sim / -e habitat-lab）
# ===========================================================
COPY requirements_clean.txt /app/requirements_clean.txt
RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/requirements_clean.txt

# ===========================================================
# 单独安装 habitat-lab（不装依赖，避免 habitat-sim 冲突）
# ===========================================================
RUN pip install --no-deps -e "git+https://ghproxy.cn/https://github.com/wsakobe/TrackVLA.git@670f0f06e23ed3e69536f171986076ad63dc3aea#egg=habitat_lab&subdirectory=habitat-lab"
# 若网络可直连 GitHub，可改为：
# RUN pip install --no-deps -e "git+https://github.com/wsakobe/TrackVLA.git@670f0f06e23ed3e69536f171986076ad63dc3aea#egg=habitat_lab&subdirectory=habitat-lab"

# ===========================================================
# 拷贝源码并清空 model_zoo（建议 .dockerignore 忽略此目录）
# ===========================================================
COPY . /app
RUN rm -rf /app/model_zoo && mkdir -p /app/model_zoo

# ===========================================================
# 默认启动命令
# ===========================================================
CMD ["python", "test.py"]

