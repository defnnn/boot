package boot

import (
	"tool/exec"
)

c: {
	image: string
	input: {
		cmd:  string
		args: string
		arg1: string
		arg2: string
		arg3: string
		arg4: string
		arg5: string
		arg6: string
		arg7: string
		arg8: string
		arg9: string
	}

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
