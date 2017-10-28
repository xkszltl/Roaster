# ================================================================
# Nagios
# ================================================================

[ -e $STAGE/nagios ] && ( set -e
    setsebool -P daemons_enable_cluster_mode 1 || $IS_CONTAINER

    mkdir -p $SCRATCH/nagios-selinux
    cd $_

    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF > nagios-statusjsoncgi.te
module nagios-statusjsoncgi 1.0;
require {
  type nagios_script_t;
  type nagios_spool_t;
  class file { getattr read open };
}
allow nagios_script_t nagios_spool_t:file { getattr read open };
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    checkmodule -M -m -o nagios-statusjsoncgi.{mod,te}
    semodule_package -m nagios-statusjsoncgi.mod -o nagios-statusjsoncgi.pp
    semodule -i $_

    systemctl daemon-reload || $IS_CONTAINER
    for i in nagios; do :
    #     systemctl enable $i
    #     systemctl start $i || $IS_CONTAINER
    done

    cd
    rm -rvf $SCRATCH/nagios-selinux
) && rm -rvf $STAGE/nagios
sync || true
