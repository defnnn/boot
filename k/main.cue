package k

import (
	apps "github.com/defn/boot/k8s.io/api/apps/v1"
	core "github.com/defn/boot/k8s.io/api/core/v1"
)

service:    core.#Service
deployment: apps.#Deployment
