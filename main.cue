package boot

import (
	"github.com/defn/boot/project"
	"github.com/defn/boot/devcontainer"
)

#BootContext: {
	project.#Project
	devcontainer.#DevContainer
}

bootContext: #BootContext & {
	codeowners: ["@jojomomojo", "@amanibhavam"]
}
