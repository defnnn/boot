package boot

import (
	"strings"
	"encoding/yaml"
	"text/template"
	"tool/exec"
	"tool/file"
)

#Plugin: {
	plugin: string
	commands: {...}
	...
}

#Bundle: #Plugin & {
	plugin:             "repo"
	upstream_manifest:  string | *""
	upstream_kustomize: string | *""
	chart_repo:         string | *""
	variants:           {...} | *{base: values: {}}
	variants: [string]: values: {...} | *{}
	repo_name: string
	namespace: string | *""

	commands: {
		if upstream_manifest != "" {
			upstreamManifest="upstream-manifest": exec.Run & {
				cmd: ["curl", "-sSL", upstream_manifest]
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

		if upstream_kustomize != "" {
			upstreamKustomize="upstream-kustomize": exec.Run & {
				cmd: ["kustomize", "build", upstream_kustomize]
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

		if chart_repo != "" {
			upstreamHelmAdd="upstream-helm-add": exec.Run & {
				cmd: ["helm", "repo", "add", repo_name, chart_repo]
			}
			upstreamHelmUpdate="upstream-helm-update": exec.Run & {
				cmd: ["helm", "repo", "update"]
				$after: upstreamHelmAdd
			}

			for vname, v in variants {
				let upstream = [
					if vname != "base" {"upstream-\(vname)"},
					"upstream",
				][0]

				upstreamHelmValues="upstream-helm-values-\(vname)": file.Create & {
					filename: "\(upstream)/values.yaml"
					contents: yaml.Marshal(v.values)
				}
				upstreamManifest="upstream-manifest-\(vname)": exec.Run & {
					cmd: ["helm", "template", install, "\(repo_name)/\(chart_name)",
						"--include-crds",
						"--kube-version", "1.21",
						"--version=\(chart_version)",
						"--values=\(upstreamHelmValues.filename)",
						if namespace != "" {
							"--namespace=\(namespace)"
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

#Python: #Plugin & {
	plugin:   "python"
	language: "python"

	commands: {
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
}

#Boot: #Plugin & {
	plugin:  "boot"
	module:  string
	version: string
	templates: {...}

	commands: {
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
}

#ArgoCD: #Plugin & {
	plugin: "argocd"
	projects: [...#ArgoProject]
	clusters: {
		[string]: [...#ArgoApplication]
	}

	commands: {
		"argocd-project": file.Create & {
			filename: "a/projects.yaml"
			contents: yaml.MarshalStream(projects)
		}
		for cname, apps in clusters {
			"argocd-cluster-\(cname)": file.Create & {
				filename: "a/cluster-\(cname).yaml"
				contents: yaml.Marshal(apps)
			}
		}
	}
}

#Kustomize: #Plugin & {
	plugin: "kustomize"
	clusters: {
		[string]: [...#DeployBase]
	}

	commands: {
		for cname, apps in clusters for a in apps {
			let M = file.Create & {
				filename: strings.ToLower("c/\(cname)/\(a.aname)/kustomization.yaml")
				contents: yaml.Marshal(a.output)
			}
			"kustomization-\(cname)-\(a.aname)": M

			for rname, r in a.resources {
				let N = file.Create & {
					filename: strings.ToLower("c/\(cname)/\(a.aname)/resource-\(r.kind)-\(r.metadata.name).yaml")
					contents: yaml.Marshal(r)
				}
				"resource-\(cname)-\(a.aname)-\(r.kind)-\(r.metadata.name)": N
			}
			for pname, p in a.patches {
				let O = file.Create & {
					filename: strings.ToLower("c/\(cname)/\(a.aname)/patch-\(pname).yaml")
					contents: yaml.Marshal(p.ops)
				}
				"patch-\(cname)-\(a.aname)-\(pname)": O
			}
		}
	}
}

#Plugins: {
	cfg: {...}

	vendor: exec.Run & {
		cmd: "hof mod vendor cue"
	}

	hello: exec.Run & {
		cmd: "echo hello v29"
	}

	{
		for cname, c in cfg {
			if (c & #Python) != _|_ {
				py: #Command & {cfg: c}
			}

			if (c & #Bundle) != _|_ {
				bundle: #Command & {cfg: c}
			}

			if (c & #Boot) != _|_ {
				boot: #Command & {cfg: c}
			}

			if (c & #ArgoCD) != _|_ {
				argocd: #Command & {cfg: c}
			}

			if (c & #Kustomize) != _|_ {
				kustomize: #Command & {cfg: c}
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

_boot: CFG=#Boot & {
	templates: {
		cueMod:  """
			module: "\(module)"
			"""
		cueMods: """
			module \(module)

			cue v0.4.0

			require (
				github.com/defn/boot \(version)
			)
			"""
		bootCue: """
			package boot

			import "github.com/defn/boot"

			cfg: "boot": boot.#Boot

			"""
		bootTool: """
			package boot

			import (
				"github.com/defn/boot"
			)

			cfg: {...} | *{}

			command: boot.#Plugins & {
				"cfg": cfg
			}

			"""
		gitignore: """
			cue.mod/pkg/
			"""
	}
}
