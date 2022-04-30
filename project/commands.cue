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
				    rev: v4.1.0
				    hooks:
				      - id: trailing-whitespace
				      - id: end-of-file-fixer

				  - repo: https://github.com/pre-commit/mirrors-prettier
				    rev: v2.5.1
				    hooks:
				      - id: prettier

				  - repo: https://github.com/gruntwork-io/pre-commit
				    rev: v0.1.17
				    hooks:
				      - id: shellcheck

				  - repo: local
				    hooks:
				      - id: cue-fmt
				        name: cue-fmt
				        entry: bash -c 'for a in "$@"; do cue fmt --simplify "$a"; done' ''
				        language: system
				        files: '\\.cue$'
				        pass_filenames: true

				  - repo: local
				    hooks:
				      - id: sh-fmt
				        name: sh-fmt
				        entry: shfmt -w
				        language: system
				        files: "^(bin|etc)/"
				        pass_filenames: true

				"""
			filename: ".pre-commit-config.yaml"
			contents: template.Execute(_template, _data)
		}
		configureProjectPreCommitInstall: exec.Run & {
			$after: configureProjectPreCommitConfig
			cmd: ["pre-commit", "install"]
		}

		configureProjectMakefile: file.Create & {
			_data: {
			}
			_template: """
				-include Makefile.site
				update:
					git pull
					hof mod vendor cue

				"""
			filename: "GNUmakefile"
			contents: template.Execute(_template, _data)
		}
	}
}
