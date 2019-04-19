# Build with "docker build --pull --no-cache -t docker.codingcafe.org/xkszltl/roaster git@git.codingcafe.org:xkszltl/roaster.git"

FROM centos

SHELL ["/bin/bash", "-c"]

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:/usr/local/nvidia/lib:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES all

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]

COPY ["setup.sh", "/etc/roaster/"]
COPY ["pkgs", "/etc/roaster/pkgs"]
COPY ["cache.repo", "/etc/yum.repos.d/"]
VOLUME ["/var/log"]

RUN cp -f /etc/hosts /tmp && echo 10.0.0.10 {proxy,repo}.codingcafe.org > /etc/hosts && /etc/roaster/setup.sh && cat /tmp/hosts > /etc/hosts && rm -f /tmp/hosts
