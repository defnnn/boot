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
	variants:           {...} | *{base: values: {}}
	variants: [string]: values: {...} | *{}
	repo_name: string
	namespace: string | *""
	...
}

#Command: {
	repo: #Repo

	if repo.upstream_manifest != "" {
		upstreamManifest="upstream-manifest": exec.Run & {
			cmd: ["curl", "-sSL", repo.upstream_manifest]
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

	if repo.upstream_kustomize != "" {
		upstreamKustomize="upstream-kustomize": exec.Run & {
			cmd: ["kustomize", "build", repo.upstream_kustomize]
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

	if repo.chart_repo != "" {
		upstreamHelmAdd="upstream-helm-add": exec.Run & {
			cmd: ["helm", "repo", "add", repo.repo_name, repo.chart_repo]
		}
		upstreamHelmUpdate="upstream-helm-update": exec.Run & {
			cmd: ["helm", "repo", "update"]
			$after: upstreamHelmAdd
		}

		for vname, v in repo.variants {
			let upstream = [
				if vname != "base" {"upstream-\(vname)"},
				"upstream",
			][0]

			upstreamHelmValues="upstream-helm-values-\(vname)": file.Create & {
				filename: "\(upstream)/values.yaml"
				contents: yaml.Marshal(v.values)
			}
			upstreamManifest="upstream-manifest-\(vname)": exec.Run & {
				cmd: ["helm", "template", repo.install, "\(repo.repo_name)/\(repo.chart_name)",
					"--include-crds",
					"--kube-version", "1.21",
					"--version=\(repo.chart_version)",
					"--values=\(upstreamHelmValues.filename)",
					if repo.namespace != "" {
						"--namespace=\(repo.namespace)"
					},
				]
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
