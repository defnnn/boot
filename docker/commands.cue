package docker

import (
	"tool/exec"
	"github.com/defn/boot"
)

#DockerConfig: {
	image: string
}

#Docker: {
	boot.#BootInput
	#DockerConfig
	...
}

commands: ctx=#Docker & {
	build: {
		dockerBuild: exec.Run & {
			cmd: ["docker", "build", "-t", ctx.image, "."]
		}
	}

	push: {
		dockerPush: exec.Run & {
			cmd: ["docker", "push", ctx.image]
		}
	}
}
