package k3d

import (
	"encoding/yaml"
	"tool/exec"
	"tool/file"
	"github.com/defn/boot/input"
)

#K3D: ctx={
	input.#Input
	#K3DConfig

	config: {
		saveConfig: file.Create & {
			filename: "k3d.yaml"
			contents: yaml.Marshal(ctx.output)
		}
	}

	"k3d-registry": {
		createRegistry: exec.Run & {
			cmd: ["k3d", "registry", "create", "registry.localhost", "--port", "5555"]
		}
	}

	up: {
		createCluster: exec.Run & {
			cmd: ["k3d", "cluster", "create", "--config", "k3d.yaml"]
		}
	}

	down: {
		deleteCluster: exec.Run & {
			cmd: ["k3d", "cluster", "delete", ctx.k3d_name]
		}
	}

	context: {
		createCluster: exec.Run & {
			cmd: ["kubectl", "config", "use-context", "k3d-\(ctx.name)"]
		}
	}

}
