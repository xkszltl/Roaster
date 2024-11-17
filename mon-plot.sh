#!/bin/bash

set -e

for cmd in grep hostname journalctl jq python3 sed; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "$s".\033[0m\n' "$cmd" >&2
    exit 1
done

for pkg in matplotlib numpy; do
    ! python3 -m pip show "$pkg" >/dev/null || continue
    printf '\033[31m[ERROR] Missing python lib "%s".\033[0m\n' "$pkg" >&2
    exit 1
done

[ "$win" ] || win='1h'

sudo -v

# Known issue:
# - systemd 219 (on CentOS 7) prints UTF-8 bytes as sequence of \u<64-bit hex>.
#   Convert some simple cases to \u<32-bit hex> of unicode.
sudo journalctl --no-pager --since "-$win" --until now -o json -u{sensors,ipmi}-mon                 \
| sed 's/\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Cc]2\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff]\([0-9A-Fa-f][0-9A-Fa-f]\)/\\u00\1/g' \
| sed 's/\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Cc]3\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff]8\([0-9A-Fa-f]\)/\\u00c\1/g'          \
| sed 's/\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Cc]3\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff]9\([0-9A-Fa-f]\)/\\u00d\1/g'          \
| sed 's/\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Cc]3\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Aa]\([0-9A-Fa-f]\)/\\u00e\1/g'       \
| sed 's/\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Cc]3\\[Uu][Ff][Ff][Ff][Ff][Ff][Ff][Bb]\([0-9A-Fa-f]\)/\\u00f\1/g'       \
| jq -er 'select(.SYSLOG_IDENTIFIER == "sh")'                                                       \
| jq -er '.__REALTIME_TIMESTAMP + "000 - '"$(date +'%s%N')"'; " + .MESSAGE'                         \
| sed 's/[[:space:]][[:space:]]*/ /g'                                                               \
| grep -i                                                                                           \
    -e'; '{'power1','Sensor 2'}                                                                     \
    -e'; '{'MB','System'}' Temp'                                                                    \
    -e'; '{{'CPU','VRMCpu'}{,'2'},'Vcpu'{,'2'}'VRM'}' Temp'                                         \
    -e'; '{'DDR4_E',{,'P2-'}'DIMM'{'E1','E~H'}}' Temp'                                              \
    -e'; ''12V'                                                                                     \
| sed 's/ *[|:] */; /'                                                                              \
| cut -d'|' -f1                                                                                     \
| tr -d '+'                                                                                         \
| sed 's/°C.*//'                                                                                    \
| sed 's/ W.*//'                                                                                    \
| sed 's/[Nn]\/[Aa].*/nan/'                                                                         \
| sed 's/^ *//'                                                                                     \
| sed 's/ *$//'                                                                                     \
| sed -n 's/^\([^;]*\); \([^;]*\); \([^;]*\)$/stat\.setdefault("\2", \[\]).append(\[\1, \3\])/p'    \
| tr 'A-Z' 'a-z'                                                                                    \
| sed 's/inf/0/g'                                                                                   \
| sed 's/nan/0/g'                                                                                   \
| sed 's/"power[0-9]"/"Power"/'                                                                     \
| sed 's/"sensor 2"/"T_ssd"/'                                                                       \
| sed 's/"cpu[0-9]* temp"/"T_cpu"/'                                                                 \
| sed 's/"vrmcpu[0-9]* temp"/"T_vrm"/'                                                              \
| sed 's/"vcpu[0-9]*vrm temp"/"T_vrm"/'                                                             \
| sed 's/"system temp"/"T_sys"/'                                                                    \
| sed 's/"mb temp"/"T_sys"/'                                                                        \
| sed 's/"p[0-9][_\-]dimm[a-z][^ ]* temp"/"T_mem"/'                                                 \
| sed 's/"dimm[a-z][^ ]* temp"/"T_mem"/'                                                            \
| sed 's/"12v"/"12V"/'                                                                              \
| paste -sd';' -                                                                                    \
| sed 's/^/stat = {};/'                                                                             \
| sed 's/$/\n'"$(set -e +x >&2
        printf '%s\n' '
                import matplotlib
                import matplotlib.pyplot
                import numpy as np

                max_sample = 2000
                dat = {
                    k: np.flip(np.flip(np.array(v, dtype=np.float64))[::(len(v) + max_sample - 1) // max_sample]).transpose()
                    for (k, v) in stat.items()
                }
                matplotlib.rcParams["lines.linewidth"] = min(1e3 / max(i.shape[1] for i in dat.values()), 1)
                (fig, ax) = matplotlib.pyplot.subplots(figsize=(16, 9))
                ax.set_title("'"$win System Monitoring ($(hostname))"'")
                ax.set_xlabel("time [d]")
                ax.set_ylabel("temperature [℃]")
                y_v = ax.secondary_yaxis(1.0, functions=(lambda x: x / 5, lambda x: x * 5))
                y_v.set_ylabel("voltage (V)")
                y_w = ax.secondary_yaxis(1.05, functions=(lambda x: x * 10, lambda x: x / 10))
                y_w.set_ylabel("wattage (W)")
                for (i, k) in (
                    ("Power", .1),
                    ("T_ssd", 1.),
                    ("T_cpu", 1.),
                    ("T_sys", 1.),
                    ("T_vrm", 1.),
                    ("T_mem", 1.),
                    ("12V",   5.),
                ):
                    if i in dat:
                        ax.plot(dat[i][0] / (86400 * 1e9), dat[i][1] * k, label=i)
                ax.legend(loc="upper left", bbox_to_anchor=(1.1, 1.0))
                fig.savefig("'"mon-$win-$(hostname).pdf"'", bbox_inches="tight")
            '                               \
        | sed 's/^    //'                   \
        | sed 's/^    //'                   \
        | sed 's/^    //'                   \
        | sed 's/^    //'                   \
        | grep .                            \
        | sed 's/\([\[\\\/\.\-]\)/\\\1/g'   \
        | paste -sd'\v' -                   \
        | sed 's/'"$(printf '\v')"'/\\n/g'
    )"'/'                                                                                           \
| python3
