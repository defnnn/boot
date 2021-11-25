package boot

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

#Boot: #Plugin & {
	plugin:  "boot"
	module:  string
	version: string
	templates: {...}
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
			if (c & #Repo) != _|_ {
				gen: #Command & {cfg: c}
			}
			if (c & #Boot) != _|_ {
				boot: #Command & {cfg: c}
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
			module: "\(CFG.module)"
			"""
		cueMods: """
			module \(CFG.module)

			cue v0.4.0

			require (
				github.com/defn/boot \(CFG.version)
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
