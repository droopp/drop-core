
def get():

    _VIP_CMDS = [
        "sudo ifconfig {iface}:0 down",
        "sudo ifconfig {iface}:0 {vip} netmask 255.255.255.255 broadcast {vip}",
        "sudo arping -I {iface} -c 2 -s {vip} {vip}"
    ]

    _RSERV_CMDS = [
        "sudo ifconfig {iface}:0 down",
    ]

    return _VIP_CMDS, _RSERV_CMDS
