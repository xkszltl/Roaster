# Build with "docker build --pull --no-cache -t docker.codingcafe.org/sandbox/centos git@git.codingcafe.org:Sandbox/CentOS.git"

FROM centos/systemd

SHELL ["/bin/bash", "-c"]

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:/usr/local/nvidia/lib:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

ADD ["setup.sh", "/etc/codingcafe/"]
ADD ["pkgs", "/etc/codingcafe/pkgs"]
ADD ["cache.repo", "/etc/yum.repos.d/"]
VOLUME ["/var/log"]

RUN cp -f /etc/hosts /tmp && echo 10.0.0.10 {git,proxy,repo}.codingcafe.org > /etc/hosts && /etc/codingcafe/setup.sh && cat /tmp/hosts > /etc/hosts && rm -f /tmp/hosts
