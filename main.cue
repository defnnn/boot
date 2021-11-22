package boot

import (
	"encoding/yaml"
	"tool/exec"
	"tool/file"
)

#Repo: {
	upstream_manifest:  string | *""
	upstream_kustomize: string | *""
	chart_repo:         string | *""
	variants:           {...} | *{}
	variants: [string]: values: {...} | *{}
	...
}

#Command: {
	rname: string
	r: #Repo

	if r.upstream_manifest != "" {
		upstreamManifest="upstream-manifest": exec.Run & {
			cmd: ["curl", "-sSL", r.upstream_manifest]
			stdout: string
		}
		upstreamWrite="upstream-write": file.Create & {
			filename: "upstream/main.yaml"
			contents: upstreamManifest.stdout
		}
		baseKustomize="base-kustomize": exec.Run & {
			cmd: ["kustomize", "build", "base"]
			stdout: string
			$after: upstreamWrite
		}
		"base-write": file.Create & {
			filename: "base.yaml"
			contents: baseKustomize.stdout
		}
	}

	if r.upstream_kustomize != "" {
		upstreamKustomize="upstream-kustomize": exec.Run & {
			cmd: ["kustomize", "build", r.upstream_kustomize]
			stdout: string
		}
		upstreamWrite="upstream-write": file.Create & {
			filename: "upstream/main.yaml"
			contents: upstreamKustomize.stdout
		}
		baseKustomize="base-kustomize": exec.Run & {
			cmd: ["kustomize", "build", "base"]
			stdout: string
			$after: upstreamWrite
		}
		"base-write": file.Create & {
			filename: "base.yaml"
			contents: baseKustomize.stdout
		}
	}

	if r.chart_repo != "" {
		upstreamHelmAdd="upstream-helm-add": exec.Run & {
			cmd: ["helm", "repo", "add", rname, r.chart_repo]
		}
		upstreamHelmUpdate="upstream-helm-update": exec.Run & {
			cmd: ["helm", "repo", "update"]
			$after: upstreamHelmAdd
		}

		for vname, v in r.variants {
			let upstream = [
				if vname != "base" {"upstream-\(vname)"},
				"upstream",
			][0]

			upstreamHelmValues="upstream-helm-values-\(vname)": file.Create & {
				filename: "\(upstream)/values.yaml"
				contents: yaml.Marshal(v.values)
			}
			upstreamManifest="upstream-manifest-\(vname)": exec.Run & {
				cmd: ["helm", "template", r.install, "\(rname)/\(r.chart_name)",
					"--include-crds",
					"--kube-version", "1.21",
					"--version=\(r.chart_version)",
					"--namespace=\(r.namespace)",
					"--values=\(upstreamHelmValues.filename)"]
				stdout: string
				$after: [upstreamHelmUpdate, upstreamHelmValues]
			}

			upstreamWrite="upstream-write-\(vname)": file.Create & {
				filename: "\(upstream)/main.yaml"
				contents: upstreamManifest.stdout
			}
			variantKustomize="variant-kustomize-\(vname)": exec.Run & {
				cmd: ["kustomize", "build", vname]
				stdout: string
				$after: upstreamWrite
			}
			"variant-write-\(vname)": file.Create & {
				filename: "\(vname).yaml"
				contents: variantKustomize.stdout
			}
		}
	}
}
