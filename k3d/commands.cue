package k3d

import (
	"encoding/yaml"
	"tool/exec"
	"tool/file"
	"tool/cli"
	"github.com/defn/boot/input"
)

#K3D: ctx={
	input.#Input
	#K3DConfig

	config: mergeKubeConfig: exec.Run & {
		cmd: ["k3d", "kubeconfig", "merge", "-d", "-s", ctx.k3d_name]
	}

	"k3d-registry": createRegistry: exec.Run & {
		cmd: ["k3d", "registry", "create", "registry.localhost", "--port", "5555"]
	}

	up: {
		saveConfig: file.Create & {
			filename: "k3d.yaml"
			contents: yaml.Marshal(ctx.output)
		}
		createCluster: exec.Run & {
			$after: saveConfig
			cmd: ["k3d", "cluster", "create", "--config", "k3d.yaml"]
		}
	}

	start: deleteCluster: exec.Run & {
		cmd: ["k3d", "cluster", "start", ctx.k3d_name]
	}

	stop: deleteCluster: exec.Run & {
		cmd: ["k3d", "cluster", "stop", ctx.k3d_name]
	}

	down: deleteCluster: exec.Run & {
		cmd: ["k3d", "cluster", "delete", ctx.k3d_name]
	}

	context: createCluster: exec.Run & {
		cmd: ["kubectl", "config", "use-context", "k3d-\(ctx.k3d_name)"]
	}

	_manifest: [
		for aname, a in ctx.app
		for kname, kinds in a.output
		for k in kinds {k}, // app: defm: output: namespace: [name]: {}
	]

	plan: cli.Print & {
		text: yaml.MarshalStream(_manifest)
	}

	apply: exec.Run & {
		stdin: yaml.MarshalStream(_manifest)
		cmd: ["kubectl", "--context", "k3d-\(ctx.k3d_name)", "apply", "-f", "-"]
	}

	watch: exec.Run & {
		cmd: ["tilt", "up", "--context", "k3d-\(ctx.k3d_name)"]
	}

	dev: exec.Run & {
		appNames: [ for aname, a in ctx.app {aname}]

		remoteFolder: string | *"/home/ubuntu"
		if len(ctx.arg) > 0 {
			remoteFolder: ctx.arg[0]
		}

		if len(appNames) > 0 {
			appName: appNames[0]
			cmd: ["code", "--folder-uri", "vscode-remote://k8s-container+namespace=\(appName)+podname=\(appName)+name=defn+context=k3d-\(ctx.k3d_name)+image=\(ctx.k3d_name)+\(remoteFolder)"]
		}
		if len(appNames) == 0 {
			cmd: ["echo", "not-implemented"]
		}
	}
}
