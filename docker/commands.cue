package docker

import (
	"tool/exec"
	"github.com/defn/boot/input"
)

#DockerConfig: image: string

#Docker: ctx={
	input.#Input
	#DockerConfig

	build: dockerBuild: exec.Run & {
		cmd: ["docker", "build", "-t", ctx.image, "."]
	}

	push: dockerPush: exec.Run & {
		cmd: ["docker", "push", ctx.image]
	}
}
