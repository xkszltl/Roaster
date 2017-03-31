FROM centos
ENV container docker
SHELL ["/bin/bash", "-c"]
ADD ["setup.sh", "/tmp/"]
RUN chmod +x /tmp/setup.sh && /tmp/setup.sh && rm -f /tmp/setup.sh
RUN rm -f /etc/systemd/system/*.wants/* /lib/systemd/system/{{multi-user,local-fs,basic,anaconda}.target.wants/*,sockets.target.wants/*{udev,initctl}*,sysinit.target.wants/systemd-tmpfiles-setup.service}
VOLUME ["/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]
