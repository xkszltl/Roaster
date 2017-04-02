# Build with "docker build --rm --pull -t docker.codingcafe.org/sandbox/centos ."

FROM centos
ENV container docker
SHELL ["/bin/bash", "-c"]
ADD ["setup.sh", "/tmp/"]
ADD ["cache.repo", "/etc/yum.repos.d/"]
RUN chmod +x /tmp/setup.sh && /tmp/setup.sh && rm -f /tmp/setup.sh
RUN rm -f /etc/systemd/system/*.wants/* /lib/systemd/system/{{multi-user,local-fs,basic,anaconda}.target.wants/*,sockets.target.wants/*{udev,initctl}*,sysinit.target.wants/systemd-tmpfiles-setup.service}
VOLUME ["/sys/fs/cgroup"]
VOLUME ["/var/log"]
RUN systemctl enable sssd
CMD ["/usr/sbin/init"]
