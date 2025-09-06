#!/bin/sh
#=============================================================================
# smp_affinity: 1 = CPU1, 2 = CPU2, 3 = CPU3, 4 = CPU4
# rps_cpus: wxyz = CPU3 CPU2 CPU1 CPU0 (ex:0xd = 0'b1101 = CPU1, CPU3, CPU4)
#=============================================================================
#. /sbin/config.sh
if [ ! -n "$1" ]; then
  echo "insufficient arguments!"
  echo "Usage: $0 <mode>"
  exit 0
fi
OPTIMIZED_FOR="$1"
LIST=`cat /proc/interrupts | sed -n '1p'`
NUM_OF_CPU=0; for i in $LIST; do NUM_OF_CPU=`expr $NUM_OF_CPU + 1`; done;
case `cat /proc/cpuinfo | grep MT76` in
  *7621*)
    CONFIG_RALINK_MT7621=y
    ;;
esac

if grep -Frxq "DBDC_MODE=1" /etc/wireless; then
    DBDC=1
else
    DBDC=0
fi

CONFIG_FIRST_CARD=`cat /etc/wireless/l1profile.dat | grep "INDEX0=" | cut -d '=' -f 2`
CONFIG_SECOND_CARD=`cat /etc/wireless/l1profile.dat | grep "INDEX1=" | cut -d '=' -f 2`

echo "OPTIMIZED_FOR -> $OPTIMIZED_FOR"
echo "NUM_OF_CPU -> $NUM_OF_CPU"
echo "CONFIG_RALINK_MT7621 -> $CONFIG_RALINK_MT7621"
echo "CONFIG_FIRST_CARD -> $CONFIG_FIRST_CARD"
echo "CONFIG_SECOND_CARD -> $CONFIG_SECOND_CARD"
echo "DBDC -> $DBDC"
#
# $1 - value
# $2 - proc path
#
write_proc() {
    [ -f $2 ] && {
        echo $1 > $2
        echo -n $1 ">" $2, "= "
        cat $2
    }
}


if [ $OPTIMIZED_FOR == "wifi" ]; then
    if [ $NUM_OF_CPU == "4" ]; then
        if [ "$CONFIG_RALINK_MT7621" = "y" ]; then
            write_proc 2 /proc/irq/3/smp_affinity  #GMAC
            write_proc 4 /proc/irq/4/smp_affinity  #PCIe0
            write_proc 8 /proc/irq/24/smp_affinity #PCIe1
            write_proc 8 /proc/irq/25/smp_affinity #PCIe2
            write_proc 8 /proc/irq/19/smp_affinity #VPN
            write_proc 8 /proc/irq/20/smp_affinity #SDXC
            write_proc 8 /proc/irq/22/smp_affinity #USB
            if [ "$CONFIG_FIRST_CARD" = "MT7663" ]; then
                write_proc 0 /sys/class/net/ra0/queues/rx-0/rps_cpus
                write_proc 0 /sys/class/net/apcli0/queues/rx-0/rps_cpus
                write_proc 0 /sys/class/net/wds0/queues/rx-0/rps_cpus
                write_proc 0 /sys/class/net/wds1/queues/rx-0/rps_cpus
                write_proc 0 /sys/class/net/wds2/queues/rx-0/rps_cpus
                write_proc 0 /sys/class/net/wds3/queues/rx-0/rps_cpus
            else
                write_proc 3 /sys/class/net/ra0/queues/rx-0/rps_cpus
                write_proc 3 /sys/class/net/apcli0/queues/rx-0/rps_cpus
                write_proc 3 /sys/class/net/wds0/queues/rx-0/rps_cpus
                write_proc 3 /sys/class/net/wds1/queues/rx-0/rps_cpus
                write_proc 3 /sys/class/net/wds2/queues/rx-0/rps_cpus
                write_proc 3 /sys/class/net/wds3/queues/rx-0/rps_cpus
            fi
            write_proc 3 /sys/class/net/rai0/queues/rx-0/rps_cpus
            write_proc 3 /sys/class/net/apclii0/queues/rx-0/rps_cpus
            write_proc 3 /sys/class/net/wdsi0/queues/rx-0/rps_cpus
            write_proc 3 /sys/class/net/wdsi1/queues/rx-0/rps_cpus
            write_proc 3 /sys/class/net/wdsi2/queues/rx-0/rps_cpus
            write_proc 3 /sys/class/net/wdsi3/queues/rx-0/rps_cpus
            if [ "$DBDC" = "1" ]; then
                if [ -d "/sys/class/net/rax0" ]; then
                    write_proc 3 /sys/class/net/rax0/queues/rx-0/rps_cpus
                else
                    write_proc 3 /sys/class/net/ra1/queues/rx-0/rps_cpus
                fi
                if [ -d "/sys/class/net/apclix0" ]; then
                    write_proc 3 /sys/class/net/apclix0/queues/rx-0/rps_cpus
                else
                    write_proc 3 /sys/class/net/apcli1/queues/rx-0/rps_cpus
                fi
            fi
            if [ -d "/sys/class/net/rai0" ]; then
                if [ "$CONFIG_FIRST_CARD" = "MT7615D" -a "$CONFIG_SECOND_CARD" = "MT7663" ]; then
                    write_proc 9 /sys/class/net/eth0/queues/rx-0/rps_cpus
                    write_proc 9 /sys/class/net/eth1/queues/rx-0/rps_cpus
                    echo "eth0/eth1 RPS: CPU0/3"
                else
                    write_proc 5 /sys/class/net/eth0/queues/rx-0/rps_cpus
                    write_proc 5 /sys/class/net/eth1/queues/rx-0/rps_cpus
                    echo "eth0/eth1 RPS: CPU0/2"
                fi
            else
                if [ "$DBDC" = "1" ]; then
                    write_proc 8 /proc/irq/4/smp_affinity  #PCIe0
                    write_proc 5 /sys/class/net/eth0/queues/rx-0/rps_cpus
                    write_proc 5 /sys/class/net/eth1/queues/rx-0/rps_cpus
                    echo "eth0/eth1 RPS: CPU0/2"
                else
                    write_proc 3 /sys/class/net/eth0/queues/rx-0/rps_cpus
                    write_proc 3 /sys/class/net/eth1/queues/rx-0/rps_cpus
                    echo "eth0/eth1 RPS: CPU0/1"
                fi
            fi
        fi
    elif [ $NUM_OF_CPU == "2" ]; then
        if [ "$CONFIG_RALINK_MT7621" = "y" ]; then
            write_proc 2 /proc/irq/3/smp_affinity  #GMAC
            write_proc 1 /proc/irq/4/smp_affinity  #PCIe0
            write_proc 2 /proc/irq/24/smp_affinity #PCIe1
            write_proc 2 /proc/irq/25/smp_affinity #PCIe2
            write_proc 1 /proc/irq/19/smp_affinity #VPN
            write_proc 1 /proc/irq/20/smp_affinity #SDXC
            write_proc 1 /proc/irq/22/smp_affinity #USB
            write_proc 2 /sys/class/net/ra0/queues/rx-0/rps_cpus
            write_proc 1 /sys/class/net/rai0/queues/rx-0/rps_cpus
            write_proc 2 /sys/class/net/apcli0/queues/rx-0/rps_cpus
            write_proc 1 /sys/class/net/apclii0/queues/rx-0/rps_cpus
            write_proc 2 /sys/class/net/eth0/queues/rx-0/rps_cpus
            write_proc 2 /sys/class/net/eth1/queues/rx-0/rps_cpus
        fi
    fi
elif [ $OPTIMIZED_FOR == "storage" ]; then
    if [ $NUM_OF_CPU == "4" ]; then
        if [ "$CONFIG_RALINK_MT7621" = "y" ]; then
            write_proc 1 /proc/irq/3/smp_affinity  #GMAC Tx/Rx
            write_proc 2 /proc/irq/4/smp_affinity  #PCIe0
            write_proc 2 /proc/irq/24/smp_affinity #PCIe1
            write_proc 2 /proc/irq/25/smp_affinity #PCIe2
            write_proc 4 /proc/irq/19/smp_affinity #VPN
            write_proc 4 /proc/irq/20/smp_affinity #SDXC
            write_proc 4 /proc/irq/22/smp_affinity #USB
        fi
        write_proc 2 /sys/class/net/ra0/queues/rx-0/rps_cpus
        write_proc 2 /sys/class/net/rai0/queues/rx-0/rps_cpus
        write_proc 2 /sys/class/net/eth0/queues/rx-0/rps_cpus
        write_proc 2 /sys/class/net/eth1/queues/rx-0/rps_cpus
    elif [ $NUM_OF_CPU == "2" ]; then
        if [ "$CONFIG_RALINK_MT7621" = "y" ]; then
            write_proc 1 /proc/irq/3/smp_affinity  #GMAC
            write_proc 1 /proc/irq/4/smp_affinity  #PCIe0
            write_proc 1 /proc/irq/24/smp_affinity #PCIe1
            write_proc 1 /proc/irq/25/smp_affinity #PCIe2
            write_proc 1 /proc/irq/19/smp_affinity #VPN
            write_proc 1 /proc/irq/20/smp_affinity #SDXC
            write_proc 1 /proc/irq/22/smp_affinity #USB
        fi
    write_proc 1 /sys/class/net/ra0/queues/rx-0/rps_cpus
    write_proc 1 /sys/class/net/rai0/queues/rx-0/rps_cpus
    write_proc 1 /sys/class/net/eth0/queues/rx-0/rps_cpus
    write_proc 1 /sys/class/net/eth1/queues/rx-0/rps_cpus
    fi
else
    echo "unknow arguments!"
    exit 0
fi
