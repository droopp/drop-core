
def get(_strgy):

    _VIP_CMDS = [
        "/opt/drop-plgn-vip-{}/up {iface} {vip}".format(_strgy),
    ]

    _RSERV_CMDS = [
        "/opt/drop-plgn-vip-{}/down {iface} {vip}".format(_strgy),
    ]

    return _VIP_CMDS, _RSERV_CMDS
