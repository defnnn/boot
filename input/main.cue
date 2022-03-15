package input

import (
	"encoding/base64"
	"strings"
)

#Input: {
	args: string
	arg: [ for a in strings.Split(args, " ") {"\(base64.Decode(null, a))"}]
}
