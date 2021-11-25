package boot

import (
	"strings"
)

#ArgoProject: {
	_cluster:   string
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "AppProject"
	metadata: {
		name:      _cluster
		namespace: "argocd"
	}
	spec: {
		sourceRepos: [
			"*",
		]
		destinations: [{
			namespace: "*"
			server:    "*"
		}]
		clusterResourceWhitelist: [{
			group: "*"
			kind:  "*"
		}]
		orphanedResources: {
			warn: false
			ignore: [{
				group: "cilium.io"
				kind:  "CiliumIdentity"
			}]
		}
	}
}

#ArgoApplication: {
	_cluster:   string
	_app:       string
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "Application"
	metadata: {
		name:      "\(_cluster)--\(_app)"
		namespace: "argocd"
	}
	spec: {
		project: _cluster
		source: {
			repoURL:        string | *'https://github.com/amanibhavam/deploy'
			path:           string | *"c/\(_cluster)/\(_app)"
			targetRevision: string | *"master"
		}
		destination: {
			name:      _cluster
			namespace: string | *_app
		}
		syncPolicy: {
			automated: {
				prune:    true
				selfHeal: true
			}
			syncOptions: [ string] | *[ "CreateNamespace=true"]
		}
	}
}

#DeployBase: {
	apiVersion: "kustomize.config.k8s.io/v1beta1"
	kind:       "Kustomization"

	_cname:  string
	_aname:  string
	_domain: string

	_upstream:  string
	_resources: [...] | *[]

	resources: [_upstream] + [
			for rname, r in _resources {
			strings.ToLower("resource-\(r.kind)-\(r.metadata.name).yaml")
		},
	]

	_patches: {...} | *{}

	patches: [
		for pname, p in _patches {
			path: strings.ToLower("patch-\(pname).yaml")
			target: {
				kind: p.kind
				name: p.name
			}
		},
	]
}
