package k

import (
    app "k8s.io/api/apps/v1"
    core "k8s.io/api/core/v1"
)

a: app.#StatefulSet & {
    metadata: labels: defn: "cool"
}

n: core.#Namespace & {
    metadata: labels: defn: "beans"
}