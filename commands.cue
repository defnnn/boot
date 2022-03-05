package boot

import (
	"tool/exec"
)

#BootConfig: {
	greeting: string | *"hello"
}

#Boot: {
	#BootInput
	#BootConfig
	...
}

commands: ctx=#Boot & {
	dev: {
		dockerBuild: exec.Run & {
			cmd: ["devcontainer", "open"]
		}
	}

	hello: {
		dockerBuild: exec.Run & {
			cmd: ["echo", ctx.greeting, ctx.cmd, ctx.arg1, ctx.arg2]
		}
	}
}
