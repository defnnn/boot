package project

import (
	"text/template"
	"tool/file"
	"tool/exec"
	"strings"
	"github.com/defn/boot/input"
)

#ProjectConfig: codeowners: [...string]

#Project: ctx={
	input.#Input
	#ProjectConfig

	update: updateCueModulesWithHof: exec.Run & {
		cmd: ["hof", "mod", "vendor", "cue"]
	}

	config: {
		configureProjectGithubDir: exec.Run & {
			cmd: ["mkdir", "-p", ".github"]
		}

		configureProjectCodeOwners: file.Create & {
			$after: configureProjectGithubDir
			_data: owners: strings.Join(ctx.codeowners, " ")
			_template: """
				* {{ .owners }}

				"""
			filename: ".github/CODEOWNERS"
			contents: template.Execute(_template, _data)
		}

		configureProjectPreCommitConfig: file.Create & {
			$after: configureProjectGithubDir
			_data: {
			}
			_template: """
				repos:
				  - repo: https://github.com/pre-commit/pre-commit-hooks
				    rev: v4.2.0
				    hooks:
				      - id: trailing-whitespace
				        exclude: ^(provider|cdktf.out)/|\\.lock
				      - id: end-of-file-fixer
				        exclude: ^(provider|cdktf.out)/|\\.lock
				      - id: check-json
				        exclude: ^(provider|cdktf.out)/
				      - id: check-yaml
				        exclude: ^(provider|cdktf.out)/
				      - id: check-toml
				        exclude: ^(provider|cdktf.out)/
				      - id: check-shebang-scripts-are-executable
				      - id: check-executables-have-shebangs

				"""
			filename: ".pre-commit-config.yaml"
			contents: template.Execute(_template, _data)
		}
		configureProjectPreCommitInstall: exec.Run & {
			$after: configureProjectPreCommitConfig
			cmd: ["pc", "install"]
		}

		configureProjectMakefile: file.Create & {
			_data: {
			}
			_template: """
				SHELL := /bin/bash

				menu: # This menu
					@perl -ne 'printf("%10s: %s\\n","$$1","$$2") if m{^([\\w+-]+):[^#]+#\\s(.+)$$}' $(shell ls -d GNUmakefile Makefile.* 2>/dev/null)

				-include Makefile.site

				update: # Update git repo and cue libraries
					git pull
					hof mod vendor cue
					@echo; echo 'To update configs: c config'; echo

				"""
			filename: "GNUmakefile"
			contents: template.Execute(_template, _data)
		}
	}
}
