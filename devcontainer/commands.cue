package devcontainer

import (
	"text/template"
	"tool/file"
	"github.com/defn/boot/input"
)

#DevContainerConfig: {
	codeowners: [...string]
}

#DevContainer: {
	input.#Input
	#DevContainerConfig

	config: {
		configureDevContainerDir: file.Mkdir & {
			path: ".devcontainer"
		}

		configureDevContainerConfig: file.Create & {
			$after: configureDevContainerDir
			_data: {
			}
			_template: """
{
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "ubuntu",
  "mounts": [
    "source=${localEnv:HOME}/.password-store,target=/home/ubuntu/.password-store,type=bind,consistency=cached",
    "source=${localEnv:HOME}/.kube,target=/home/ubuntu/.kube,type=bind,consistency=cached"
  ],
  "runArgs": ["-v", "/var/run/docker.sock:/var/run/docker.sock"],
  "postStartCommand": "/home/ubuntu/etc/hook-start"
}

"""
			filename: ".devcontainer/devcontainer.json"
			contents: template.Execute(_template, _data)
		}
	}
}
