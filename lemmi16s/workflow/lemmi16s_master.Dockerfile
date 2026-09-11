from ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update --fix-missing
RUN apt-get install git-all -y --fix-missing

ENV PACKAGES make gcc wget libc6-dev zlib1g-dev ca-certificates xz-utils
RUN apt-get update --fix-missing -y && apt-get install -y --no-install-recommends ${PACKAGES}
RUN apt-get install zip unzip
RUN apt-get install bc -y
RUN apt-get install libbz2-dev liblzma-dev -y

RUN apt-get update --fix-missing
RUN apt-get install python3-pip -y
RUN pip3 install -U numpy joblib HTSeq pybedtools pysam scikit-learn==0.22 scipy six
RUN cp /usr/bin/python3 /usr/bin/python
RUN pip install pandas

RUN apt-get install npm -y
ADD lemmi16s_frontend /lemmi16s_frontend
WORKDIR /lemmi16s_frontend
RUN npm install --force
RUN python -m pip install pandas
RUN pip install biopython

#LEMMI16s tools and scripts

#install hyperex
WORKDIR /
RUN yes | apt install cargo
RUN cargo install hyperex
RUN cp /root/.cargo/bin/hyperex /usr/bin/

WORKDIR /LEMMI16s_tools
#install selectFasta
RUN wget https://github.com/andvides/selectFasta/releases/download/v3.1/selectFasta_v3.1.zip
RUN unzip selectFasta_v3.1.zip 
RUN make -C selectFasta_v3.1
RUN cp selectFasta_v3.1/selectFasta /usr/bin/

#Install seqkit
RUN wget https://github.com/shenwei356/seqkit/releases/download/v2.3.1/seqkit_linux_amd64.tar.gz
RUN tar -zxvf seqkit_linux_amd64.tar.gz
RUN cp seqkit /usr/bin/

#Install ART simulator
WORKDIR /
ADD resources/art_bin_MountRainier /art
ENV PATH="/art:${PATH}"

WORKDIR /LEMMI16s_tools 
# Download and install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    chmod +x /tmp/miniconda.sh && \
    /tmp/miniconda.sh -b -p /miniconda && \
    rm /tmp/miniconda.sh

# Set the path for Miniconda
ENV PATH="/miniconda/bin:$PATH"

#install QIIME2 qiime2-2023.2
RUN wget https://data.qiime2.org/distro/core/qiime2-2023.2-py38-linux-conda.yml
RUN conda update -n base -c defaults conda 
RUN conda env create -n qiime2-2023.2 --file qiime2-2023.2-py38-linux-conda.yml

RUN conda run -n qiime2-2023.2 /bin/bash -c \
    "source activate qiime2-2023.2 && \
    echo 'Running commands within qiime2-2023.2 environment' && \
    pip install git+https://github.com/bokulich-lab/q2-types-genomics.git@2023.2.0.dev0  &&\
    pip install ncbi-datasets-pylib && \
    pip install git+https://github.com/bokulich-lab/RESCRIPt.git && \
    qiime dev refresh-cache && \
    conda deactivate"
RUN mkdir /.config; chmod a+rwX /.config
RUN mkdir /.cache; chmod a+rwX /.cache

RUN python -m pip install pandas 
RUN python -m pip install biopython

#copy scripts
ADD resources/*.sh /usr/bin/ 
ADD resources/*.py /usr/bin/ 


