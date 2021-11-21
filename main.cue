package boot

repos: {
	"katt-argocd": {
		version:           "2.1.6"
		upstream_manifest: "https://raw.githubusercontent.com/argoproj/argo-cd/v\(version)/manifests/install.yaml"
	}
	"katt-argo-workflows": {
		version:           "3.2.4"
		upstream_manifest: "https://raw.githubusercontent.com/argoproj/argo-workflows/v\(version)/manifests/quick-start-postgres.yaml"
	}
	"katt-cilium": {
		chart_repo:    "https://helm.cilium.io"
		chart_name:    "cilium"
		chart_version: "1.11.0-rc2"
		install:       "cilium"
		namespace:     "kube-system"
		values: {
			hubble: {
				ui: enabled:    true
				relay: enabled: true
			}
			operator: replicas:    1
			hostServices: enabled: false
			bpf: masquerade:       false
		}
	}
}

repos: [string]: upstream_manifest: string | *""
repos: [string]: chart_repo:        string | *""
