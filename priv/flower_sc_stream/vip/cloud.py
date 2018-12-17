

def get(_strgy):

    _VIP_CMDS = [
        "/opt/drop-plgn-vip-" + _strgy+ "/up {iface} {vip}",
    ]

    _RSERV_CMDS = [
        "/opt/drop-plgn-vip-" + _strgy + "/down {iface} {vip}",
    ]

    return _VIP_CMDS, _RSERV_CMDS

