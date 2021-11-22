package boot

import (
	"encoding/yaml"
	"tool/exec"
	"tool/file"
)

command: {
	for rname, r in repos {
		"boot-\(rname)": {
			let boot = command["boot-\(rname)"]

			if r.upstream_manifest != "" {
				"upstream-manifest": exec.Run & {
					cmd: ["curl", "-sSL", r.upstream_manifest]
					stdout: string
				}
				"upstream-write-": file.Create & {
					filename: "../\(rname)/upstream/main.yaml"
					contents: boot["upstream-manifest"].stdout
				}
				"base-kustomize": exec.Run & {
					cmd: ["kustomize", "build", "../\(rname)/base"]
					stdout: string
					$after: boot["upstream-write"]
				}
				"base-write": file.Create & {
					filename: "../\(rname)/base.yaml"
					contents: boot["base-kustomize"].stdout
				}
			}

			if r.upstream_kustomize != "" {
				"upstream-kustomize": exec.Run & {
					cmd: ["kustomize", "build", r.upstream_kustomize]
					stdout: string
				}
				"upstream-write-": file.Create & {
					filename: "../\(rname)/upstream/main.yaml"
					contents: boot["upstream-kustomize"].stdout
				}
				"base-kustomize": exec.Run & {
					cmd: ["kustomize", "build", "../\(rname)/base"]
					stdout: string
					$after: boot["upstream-write"]
				}
				"base-write": file.Create & {
					filename: "../\(rname)/base.yaml"
					contents: boot["base-kustomize"].stdout
				}
			}

			if r.chart_repo != "" {
				"upstream-helm-add": exec.Run & {
					cmd: ["helm", "repo", "add", rname, r.chart_repo]
				}
				"upstream-helm-update": exec.Run & {
					cmd: ["helm", "repo", "update"]
					$after: boot["upstream-helm-add"]
				}

				for vname, v in r.variants {
					let upstream = [
						if vname != "base" {"upstream-\(vname)"},
						"upstream",
					][0]

					"upstream-helm-values-\(vname)": file.Create & {
						filename: "../\(rname)/\(upstream)/values.yaml"
						contents: yaml.Marshal(v.values)
					}
					"upstream-manifest-\(vname)": exec.Run & {
						cmd: ["helm", "template", r.install, "\(rname)/\(r.chart_name)",
							"--include-crds",
							"--kube-version", "1.21",
							"--version=\(r.chart_version)",
							"--namespace=\(r.namespace)",
							"--values=\(boot["upstream-helm-values-\(vname)"].filename)"]
						stdout: string
						$after: [boot["upstream-helm-update"], boot["upstream-helm-values-\(vname)"]]
					}

					"upstream-write-\(vname)": file.Create & {
						filename: "../\(rname)/\(upstream)/main.yaml"
						contents: boot["upstream-manifest-\(vname)"].stdout
					}
					"variant-kustomize-\(vname)": exec.Run & {
						cmd: ["kustomize", "build", "../\(rname)/\(vname)"]
						stdout: string
						$after: boot["upstream-write-\(vname)"]
					}
					"variant-write-\(vname)": file.Create & {
						filename: "../\(rname)/\(vname).yaml"
						contents: boot["variant-kustomize-\(vname)"].stdout
					}
				}
			}
		}
	}
}
