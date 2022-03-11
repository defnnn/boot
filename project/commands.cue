package project

import (
	"text/template"
	"tool/file"
	"tool/exec"
	"strings"
	"github.com/defn/boot/input"
)

#ProjectConfig: {
	codeowners: [...string]
}

#Project: ctx={
	input.#Input
	#ProjectConfig

	config: {
		configureProjectGithubDir: exec.Run & {
			cmd: ["mkdir", "-p", ".github"]
		}
		configureProjectCodeOwners: file.Create & {
			$after: configureProjectGithubDir
			_data: {
				owners: strings.Join(ctx.codeowners, " ")
			}
			_template: """
				* {{ .owners }}
				"""
			filename: ".github/CODEOWNERS"
			contents: template.Execute(_template, _data)
		}
	}
}
