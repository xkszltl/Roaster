# Build with "docker build --pull --no-cache -t docker.codingcafe.org/xkszltl/roaster/centos git@git.codingcafe.org:xkszltl/roaster.git"

FROM centos

SHELL ["/bin/bash", "-c"]

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:/usr/local/nvidia/lib:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES all

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ "_$i" = '_systemd-tmpfiles-setup.service' ] || rm -f "$i"; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
    truncate -s0 ~/.bash_history
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]

# nvidia-docker
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:/usr/local/nvidia/lib:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES all

VOLUME ["/var/log"]

COPY [".", "/etc/roaster/scripts"]

RUN /etc/roaster/setup.sh
