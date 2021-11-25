package boot

import (
	"strings"
	"encoding/yaml"
	"text/template"
	"tool/exec"
	"tool/file"
)

#Command: {
	cfg: #Repo | #Python | #Boot | #ArgoCD | #Kustomize

	if cfg.plugin == "argocd" {
		"argocd-project": file.Create & {
			filename: "a/projects.yaml"
			contents: yaml.MarshalStream(cfg.projects)
		}
		for cname, apps in cfg.clusters {
			"argocd-cluster-\(cname)": file.Create & {
				filename: "a/cluster-\(cname).yaml"
				contents: yaml.MarshalStream(apps)
			}
		}
	}

	if cfg.plugin == "kustomize" {
		for cname, apps in cfg.clusters for aname, a in apps {
			"kustomization-\(cname)-\(aname)": file.Create & {
				filename: strings.ToLower("c/\(cname)/\(aname)/kustomization.yaml")
				contents: yaml.Marshal(a)
			}
			for rname, r in a._resources {
				"resource-\(cname)-\(aname)-\(r.kind)-\(r.metadata.name)": file.Create & {
					filename: strings.ToLower("c/\(cname)/\(aname)/resource-\(r.kind)-\(r.metadata.name).yaml")
					contents: yaml.Marshal(r)
				}
			}
			for pname, p in a._patches {
				"patch-\(cname)-\(aname)-\(pname)": file.Create & {
					filename: strings.ToLower("c/\(cname)/\(aname)/patch-\(pname).yaml")
					contents: yaml.Marshal(p.ops)
				}
			}
		}
	}

	if cfg.plugin == "python" {
		"python-flake8": file.Create & {
			filename: ".flake8"
			contents: template.Execute(_python.templates.flake8, {})
		}
		"python-pyproject": file.Create & {
			filename: "pyproject.toml"
			contents: template.Execute(_python.templates.pyproject, {})
		}
		"python-gitignore": file.Create & {
			filename: ".gitignore"
			contents: template.Execute(_python.templates.gitignore, {})
		}
		pythonRequirementsSite="python-requirements-site": file.Read & {
			filename: "requirements.txt.site"
			contents: string
		}
		pythonRequirements="python-requirements": file.Create & {
			filename: "requirements.txt"
			contents: template.Execute(_python.templates.requirements, {}) + "\n" + pythonRequirementsSite.contents
		}
		pythonVirtualEnv="python-virtualenv": exec.Run & {
			cmd: ["python", "-mvenv", "venv"]
		}
		pythonPipUpgrade="python-pip-upgrade": exec.Run & {
			cmd: ["venv/bin/pip", "install", "--upgrade", "pip"]
			$after: pythonVirtualEnv
		}
		"python-pip-requirements": exec.Run & {
			cmd: ["venv/bin/pip", "install", "-r", "requirements.txt"]
			$after: [pythonPipUpgrade, pythonRequirements]
		}
	}

	if cfg.plugin == "boot" {
		let tmpl = _boot & cfg
		bootTouchGitIgnoreSite="boot-touch-gitignore-site": exec.Run & {
			cmd: ["touch", ".gitignore-site"]
		}
		bootGitIgnoreSite="boot-gitignore-site": file.Read & {
			filename: ".gitignore-site"
			contents: string
			$after:   bootTouchGitIgnoreSite
		}
		"boot-gitignore": file.Create & {
			filename: ".gitignore"
			contents: template.Execute(tmpl.templates.gitignore, {}) + "\n" + bootGitIgnoreSite.contents
		}
		bootMkdirCueMod="boot-mkdir-cue-mod": exec.Run & {
			cmd: ["mkdir", "-p", "cue.mod"]
		}
		"boot-mod": file.Create & {
			filename: "cue.mod/module.cue"
			contents: template.Execute(tmpl.templates.cueMod, {})
			$after:   bootMkdirCueMod
		}
		bootMods="boot-mods": file.Create & {
			filename: "cue.mods"
			contents: template.Execute(tmpl.templates.cueMods, {})
		}
		"boot-cue": file.Create & {
			filename: "boot.cue"
			contents: template.Execute(tmpl.templates.bootCue, {})
		}
		"boot-tool": file.Create & {
			filename: "boot_tool.cue"
			contents: template.Execute(tmpl.templates.bootTool, {})
		}
		"boot-vendor": exec.Run & {
			cmd: ["hof", "mod", "vendor", "cue"]
			$after: bootMods
		}
	}

	if cfg.plugin == "repo" {
		if cfg.upstream_manifest != "" {
			upstreamManifest="upstream-manifest": exec.Run & {
				cmd: ["curl", "-sSL", cfg.upstream_manifest]
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

		if cfg.upstream_kustomize != "" {
			upstreamKustomize="upstream-kustomize": exec.Run & {
				cmd: ["kustomize", "build", cfg.upstream_kustomize]
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

		if cfg.chart_repo != "" {
			upstreamHelmAdd="upstream-helm-add": exec.Run & {
				cmd: ["helm", "repo", "add", cfg.repo_name, cfg.chart_repo]
			}
			upstreamHelmUpdate="upstream-helm-update": exec.Run & {
				cmd: ["helm", "repo", "update"]
				$after: upstreamHelmAdd
			}

			for vname, v in cfg.variants {
				let upstream = [
					if vname != "base" {"upstream-\(vname)"},
					"upstream",
				][0]

				upstreamHelmValues="upstream-helm-values-\(vname)": file.Create & {
					filename: "\(upstream)/values.yaml"
					contents: yaml.Marshal(v.values)
				}
				upstreamManifest="upstream-manifest-\(vname)": exec.Run & {
					cmd: ["helm", "template", cfg.install, "\(cfg.repo_name)/\(cfg.chart_name)",
						"--include-crds",
						"--kube-version", "1.21",
						"--version=\(cfg.chart_version)",
						"--values=\(upstreamHelmValues.filename)",
						if cfg.namespace != "" {
							"--namespace=\(cfg.namespace)"
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
}
