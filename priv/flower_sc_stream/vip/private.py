
def get():

    _VIP_CMDS = [
        "sudo ifconfig {iface}:0 down; exit 0",
        "sudo ifconfig {iface}:0 {vip} netmask 255.255.255.255 broadcast {vip}; exit 0",
        "sudo arping -I {iface} -c 2 -s {vip} {vip}; exit 0"
    ]

    _RSERV_CMDS = [
        "sudo ifconfig {iface}:0 down; exit 0",
    ]

    return _VIP_CMDS, _RSERV_CMDS
