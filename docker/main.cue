package boot

import (
	"tool/exec"
)

commands: input=#BootInput & {
	image: string

	hello: {
		dockerBuild: exec.Run & {
			cmd: ["echo", "hello", image, input.arg1, input.arg2]
		}
	}

	dev: {
		dockerBuild: exec.Run & {
			cmd: ["devcontainer", "open"]
		}
	}

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
