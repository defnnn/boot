package project

import (
	"text/template"
	"tool/file"
	"tool/exec"
	"strings"
	"github.com/defn/boot"
)

#ProjectConfig: {
	codeowners: [...string]
}

#Project: ctx={
	boot.#BootInput
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
