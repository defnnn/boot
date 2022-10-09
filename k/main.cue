package k

import (
	core "github.com/defn/boot/k8s.io/api/core/v1"
)

#MyService: {
	core.#Service

	metadata: name: =~"^meh"
}

service: #MyService
service: metadata: name: "cool"
