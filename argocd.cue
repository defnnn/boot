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

#ArgoGroupCluster: [GROUP=string]: [CLUSTER=string]: {
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "Application"
	metadata: {
		name:      "\(GROUP)--\(CLUSTER)"
		namespace: "argocd"
	}
	spec: {
		project: CLUSTER
		source: {
			repoURL:        "https://github.com/amanibhavam/deploy"
			path:           "c/\(CLUSTER)/deploy"
			targetRevision: "master"
		}
		destination: {
			name:      "in-cluster"
			namespace: "argocd"
		}
		syncPolicy: automated: {
			prune:    true
			selfHeal: true
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

#DeployKumaZone: CFG=#DeployBase & {
	_kuma_global_address: string

	_upstream: "https://github.com/letfn/katt-kuma/zone?ref=0.0.7"

	_patches: {
		"deployment-kuma-control-plane": {
			kind: "Deployment"
			name: "kuma-control-plane"
			ops: [{
				op:   "replace"
				path: "/spec/template/spec/containers/0/env/8"
				value: {
					name:  "KUMA_MULTIZONE_ZONE_GLOBAL_ADDRESS"
					value: CFG._kuma_global_address
				}
			}, {
				op:   "replace"
				path: "/spec/template/spec/containers/0/env/9"
				value: {
					name:  "KUMA_MULTIZONE_ZONE_NAME"
					value: CFG._cname
				}
			}]
		}
	}
}

#DeployKumaGlobal: #DeployBase & {
	_upstream: "https://github.com/letfn/katt-kuma/global?ref=0.0.7"
}

#DeployCilium: CFG=#DeployBase & {
	_cilium_cluster_id:        string
	_cilium_cluster_ipv4_cidr: string

	_upstream: "https://github.com/letfn/katt-cilium/base?ref=0.0.7"

	_patches: {
		"configmap-cilium-config-cluster-mesh": {
			kind: "ConfigMap"
			name: "cilium-config"
			ops: [{
				op:    "replace"
				path:  "/data/cluster-id"
				value: CFG._cilium_cluster_id
			}, {
				op:    "replace"
				path:  "/data/cluster-name"
				value: CFG._cname
			}, {
				op:    "replace"
				path:  "/data/cluster-pool-ipv4-cidr"
				value: CFG._cilium_cluster_ipv4_cidr
			}]
		}
	}
}

#DeployPihole: CFG=#DeployBase & {
	_upstream: "https://github.com/letfn/katt-pihole/base?ref=0.0.17"

	_resources: [{
		apiVersion: "traefik.containo.us/v1alpha1"
		kind:       "IngressRoute"
		metadata: {
			name:      "pihole"
			namespace: "pihole"
		}
		spec: {
			entryPoints: [ "web"]
			routes: [{
				match: "Host(`pihole.\(CFG._cname).\(CFG._domain)`)"
				kind:  "Rule"
				services: [{
					name: "pihole-web"
					port: 80
				}]
			}]
		}
	}]
}

#DeployTraefik: CFG=#DeployBase & {
	_upstream: "https://github.com/letfn/katt-traefik/relay?ref=0.0.33"

	_resources: [{
		apiVersion: "traefik.containo.us/v1alpha1"
		kind:       "IngressClass"
		metadata: {
			name: "traefik"
		}
		spec: controller: "traefik.io/ingress-controller"
	}, {
		apiVersion: "traefik.containo.us/v1alpha1"
		kind:       "IngressRoute"
		metadata: {
			name: "traefik"
		}
		spec: {
			entryPoints: [ "web"]
			routes: [{
				match: "Host(`traefik.\(CFG._cname).\(CFG._domain)`)"
				kind:  "Rule"
				services: [{
					name: "api@internal"
					kind: "TraefikService"
				}]
			}]
		}
	}]

	_patches: {
		"cluster-role-binding": {
			kind: "ClusterRoleBinding"
			name: "traefik"
			ops: [{
				"op":    "replace"
				"path":  "/subjects/0/namespace"
				"value": "traefik-\(CFG._cname)"
			}]
		}
	}
}

#DeployDockerRegistry: #DeployBase & {
	_upstream: "https://github.com/letfn/katt-docker-registry/base?ref=0.0.2"
}

#DeployArgoWorkflows: CFG=#DeployBase & {
	_upstream: "https://github.com/letfn/katt-argo-workflows/base?ref=0.0.17"

	_resources: [{
		apiVersion: "traefik.containo.us/v1alpha1"
		kind:       "Middleware"
		metadata: {
			name:      "traefik-forward-auth"
			namespace: "argo"
		}
		spec: {
			forwardAuth: {
				address: http:
					authResponseHeaders: ["X-Forwarded-User"] //traefik-forward-auth.traefik.svc.cluster.local:4181
			}
		}
	}, {
		apiVersion: "traefik.containo.us/v1alpha1"
		kind:       "IngressRoute"
		metadata: {
			name:      "argowf"
			namespace: "argo"
		}
		spec: {
			tls: certResolver: "letsencrypt"
			entryPoints: [ "websecure"]
			routes: [{
				match: "Host(`argo.\(CFG._cname).\(CFG._domain)`)"
				kind:  "Rule"
				services: [{
					name:   "argo-server"
					port:   2746
					scheme: "https"
				}]
				middlewares: [{
					name: "traefik-forward-auth"
				}]
			}]
		}
	}]
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
