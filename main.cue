package boot

import (
	"encoding/yaml"
	"text/template"
	"tool/exec"
	"tool/file"
)

#Plugin: {
	plugin: string
	...
}

#Repo: #Plugin & {
	plugin:             "repo"
	upstream_manifest:  string | *""
	upstream_kustomize: string | *""
	chart_repo:         string | *""
	variants:           {...} | *{base: values: {}}
	variants: [string]: values: {...} | *{}
	repo_name: string
	namespace: string | *""
}

#Python: #Plugin & {
	plugin:   "python"
	language: "python"
}

#Plugins: {
	cfg: {...}

	vendor: exec.Run & {
		cmd: "hof mod vendor"
	}

	{
		for cname, c in cfg {
			if (c & #Python) != _|_ {
				py: #Command & {cfg: c}
			}
			if (c & #Repo) != _|_ {
				gen: #Command & {cfg: c}
			}
		}
	}

	...
}

_python: {
	_line_length: 99
	templates: {
		flake8:    """
			[flake8]
			ignore = E203, E266, E501, W503, F403, F401
			max-line-length = \(_line_length)
			max-complexity = 18
			select = B,C,E,F,W,T4,B9
			"""
		pyproject: """
			[tool.black]
			line-length = \(_line_length)

			[tool.isort]
			profile = "black" 
			"""
		gitignore: """
			venv
			"""
		requirements: """
			black
			isort
			flake8
			"""
	}
}

#Command: {
	cfg: #Repo | #Python

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
