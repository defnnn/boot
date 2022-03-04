package boot

import (
	"tool/exec"
)

#BootInput: {
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

	...
}

commands: input=#BootInput & {
	hello: {
		dockerBuild: exec.Run & {
			cmd: ["echo", "hello", input.cmd, input.arg1, input.arg2]
		}
	}
}
