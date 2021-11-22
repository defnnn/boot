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
			}

			if r.chart_repo != "" {
				"upstream-helm-add": exec.Run & {
					cmd: ["helm", "repo", "add", rname, r.chart_repo]
				}
				"upstream-helm-update": exec.Run & {
					cmd: ["helm", "repo", "update"]
					$after: boot["upstream-helm-add"]
				}
				"upstream-helm-values": file.Create & {
					filename: "../\(rname)/upstream/values.yaml"
					contents: yaml.Marshal(r.values)
				}
				"upstream-manifest": exec.Run & {
					cmd: ["helm", "template", r.install, "\(rname)/\(r.chart_name)",
						"--include-crds",
						"--kube-version", "1.21",
						"--version=\(r.chart_version)",
						"--namespace=\(r.namespace)",
						"--values=\(boot["upstream-helm-values"].filename)"]
					stdout: string
					$after: [boot["upstream-helm-update"], boot["upstream-helm-values"]]
				}
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
				filename: "../\(rname)/main.yaml"
				contents: boot["base-kustomize"].stdout
			}
		}
	}
}
