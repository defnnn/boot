package project

import (
	"text/template"
	"tool/file"
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
		configureProject: file.Create & {
			_data: {
				owners: strings.Join(ctx.codeowners, ", ")
			}
			_template: """
				* {{ .owners }}
				"""
			filename: ".github/CODEOWNERS"
			contents: template.Execute(_template, _data)
		}
	}
}
