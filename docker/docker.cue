package boot

import (
	"tool/exec"
)

commands: #BootInput & {
	image: string

	build: {
		dockerBuild: exec.Run & {
			cmd: ["docker", "build", "-t", image, "."]
		}
	}

	push: {
		dockerPush: exec.Run & {
			cmd: ["docker", "push", image]
		}
	}
}
