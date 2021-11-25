package boot

import (
	"strings"
)

#ArgoProject: [CLUSTER=string]: {
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "AppProject"
	metadata: {
		name:      CLUSTER
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

#ArgoApplication: [CLUSTER=string]: [APP=string]: {
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "Application"
	metadata: {
		name:      "\(CLUSTER)--\(APP)"
		namespace: "argocd"
	}
	spec: {
		project: CLUSTER
		source: {
			repoURL:        string | *'https://github.com/amanibhavam/deploy'
			path:           string | *"c/\(CLUSTER)/\(APP)"
			targetRevision: string | *"master"
		}
		destination: {
			name:      CLUSTER
			namespace: string | *APP
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
