#!/bin/sh

debug_firewall() {
    iptables -t mangle -S PREROUTING
    iptables -t mangle -S wanattack
    iptables -t filter -S input_wan_rule
    iptables -t filter -S input_wan_firewall
    iptables -t filter -S forwarding_lan_rule
    iptables -t filter -S forwarding_lan_firewall
    iptables -t filter -S forwarding_wan_rule
    iptables -t filter -S forwarding_wan_firewall
    printf "\n"
}

debug_dmz() {
    iptables -t filter -S forwarding_wan_rule
    iptables -t filter -S forwarding_wan_dmz
    iptables -t nat -S prerouting_wan_rule
    iptables -t nat -S prerouting_wan_dmz
    printf "\n"
}

debug_vpn_passthru() {
    iptables -t filter -S forwarding_rule
    iptables -t filter -S vpn_passthru
    printf "\n"
}

debug_sp_forward() {
    iptables -t filter -S forwarding_wan_rule
    iptables -t filter -S forwarding_wan_sp_forward
    iptables -t nat -S prerouting_wan_rule
    iptables -t nat -S prerouting_wan_sp_forward
    iptables -t nat -S prerouting_lan_rule
    iptables -t nat -S prerouting_lan_sp_forward
    iptables -t nat -S postrouting_lan_rule
    iptables -t nat -S postrouting_lan_sp_forward
    printf "\n"
}

debug_pr_forward() {
    iptables -t filter -S forwarding_wan_rule
    iptables -t filter -S forwarding_wan_pr_forward
    iptables -t nat -S prerouting_wan_rule
    iptables -t nat -S prerouting_wan_pr_forward
    iptables -t nat -S prerouting_lan_rule
    iptables -t nat -S prerouting_lan_pr_forward
    iptables -t nat -S postrouting_lan_rule
    iptables -t nat -S postrouting_lan_pr_forward
    printf "\n"
}

debug_port_trigger() {
    iptables -t filter -S forwarding_wan_rule
    iptables -t filter -S forwarding_wan_port_trigger
    iptables -t nat -S prerouting_wan_rule
    iptables -t nat -S prerouting_wan_port_trigger
    iptables -t nat -S prerouting_lan_rule
    iptables -t nat -S prerouting_lan_port_trigger
    printf "\n"
}

debug_fwacl6() {
    ip6tables -t filter -S forwarding_wan_rule
    ip6tables -t filter -S forwarding_wan_fwacl6
    printf "\n"
}

debug_parental_control() {
    iptables -t filter -S forwarding_rule
    iptables -t filter -S parental_control
    for i in 1 2 3 4 5; do
        iptables -t filter -S pc_${i}
    done
}

debug_mgmt() {
    iptables -t filter -S input_wan_rule
    iptables -t filter -S input_wan_mgmt
    iptables -t filter -S input_lan_rule
    iptables -t filter -S input_lan_mgmt
    iptables -t nat -S prerouting_wan_rule
    iptables -t nat -S prerouting_wan_mgmt
    printf "\n"
}


usage() {
    cat <<EOF
Usage: $0 FEATURE

Features:
  firewall (fw)
  dmz
  vpn_passthru (vp)
  sp_forward (sp)
  pr_forward (pr)
  port_trigger (pt)
  fwacl6
  parental_control (pc)
  mgmt

EOF
}


case "$1" in
    firewall|fw)
        debug_firewall
        ;;
    dmz)
        debug_dmz
        ;;
    vpn_passthru|vp)
        debug_vpn_passthru
        ;;
    sp_forward|sp)
        debug_sp_forward
        ;;
    pr_forward|pr)
        debug_pr_forward
        ;;
    port_trigger|pt)
        debug_port_trigger
        ;;
    fwacl6)
        debug_fwacl6
        ;;
    parental_control|pc)
        debug_parental_control
        ;;
    mgmt)
        debug_mgmt
        ;;
    *)
        usage
        ;;
esac
