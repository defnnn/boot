package roke

import (
    "github.com/defn/boot/k3d"
)

#BootContext: {
    k3d.#K3D
}

bootContext: #BootContext & {
    k3d_name: "roke"
    k3d_host: "roke.defn.ooo"
    k3d_ip: "100.101.28.35"
}
