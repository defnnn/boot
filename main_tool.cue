package boot

import (
	"encoding/yaml"
	"tool/exec"
	"tool/file"
)

command: {
	for rname, r in repos {
		"boot-\(rname)": {
			if r.upstream_manifest != "" {
				upstreamManifest="upstream-manifest": exec.Run & {
					cmd: ["curl", "-sSL", r.upstream_manifest]
					stdout: string
				}
				upstreamWrite="upstream-write": file.Create & {
					filename: "../\(rname)/upstream/main.yaml"
					contents: upstreamManifest.stdout
				}
				baseKustomize="base-kustomize": exec.Run & {
					cmd: ["kustomize", "build", "../\(rname)/base"]
					stdout: string
					$after: upstreamWrite
				}
				"base-write": file.Create & {
					filename: "../\(rname)/base.yaml"
					contents: baseKustomize
				}
			}

			if r.upstream_kustomize != "" {
				upstreamKustomize="upstream-kustomize": exec.Run & {
					cmd: ["kustomize", "build", r.upstream_kustomize]
					stdout: string
				}
				upstreamWrite="upstream-write": file.Create & {
					filename: "../\(rname)/upstream/main.yaml"
					contents: upstreamKustomize.stdout
				}
				baseKustomize="base-kustomize": exec.Run & {
					cmd: ["kustomize", "build", "../\(rname)/base"]
					stdout: string
					$after: upstreamWrite
				}
				"base-write": file.Create & {
					filename: "../\(rname)/base.yaml"
					contents: baseKustomize.stdout
				}
			}

			if r.chart_repo != "" {
				upstreamHelmAdd="upstream-helm-add": exec.Run & {
					cmd: ["helm", "repo", "add", rname, r.chart_repo]
				}
				upsteamHelmUpdate="upstream-helm-update": exec.Run & {
					cmd: ["helm", "repo", "update"]
					$after: upstreamHelmAdd
				}

				for vname, v in r.variants {
					let upstream = [
						if vname != "base" {"upstream-\(vname)"},
						"upstream",
					][0]

					upstreamHelmValues="upstream-helm-values-\(vname)": file.Create & {
						filename: "../\(rname)/\(upstream)/values.yaml"
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
						filename: "../\(rname)/\(upstream)/main.yaml"
						contents: upstreamManifest.stdout
					}
					variantKustomize="variant-kustomize-\(vname)": exec.Run & {
						cmd: ["kustomize", "build", "../\(rname)/\(vname)"]
						stdout: string
						$after: upstreamWrite
					}
					"variant-write-\(vname)": file.Create & {
						filename: "../\(rname)/\(vname).yaml"
						contents: variantKustomize.stdout
					}
				}
			}
		}
	}
}
