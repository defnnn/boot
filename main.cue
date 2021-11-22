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
	"katt-argo-events": {
		version:           "1.4.3"
		upstream_manifest: "https://raw.githubusercontent.com/argoproj/argo-events/v\(version)/manifests/install-validating-webhook.yaml"
	}
	"katt-argo-rollouts": {
		version:           "1.0.7"
		upstream_manifest: "https://github.com/argoproj/argo-rollouts/releases/download/v\(version)/install.yaml"
	}
	"katt-traefik": {
		chart_repo:    "https://helm.traefik.io/traefik"
		chart_name:    "traefik"
		chart_version: "10.6.0"
		install:       "traefik"
		namespace:     "traefik"
		variants: {
			_commonAdditionalArguments: [
				"--providers.kubernetescrd.allowexternalnameservices=true",
				"--providers.kubernetescrd.allowCrossNamespace=false",
				"--log.level=DEBUG",
				"--accesslog=true",
				"--serverstransport.insecureskipverify=true",
				"--global.sendanonymoususage=false",
			]
			_commonConfig: {
				ports: traefik: port:             9200
				ingressRoute: dashboard: enabled: false
			}

			base: values: _commonConfig & {
				additionalArguments: _commonAdditionalArguments + [
							"--entrypoints.websecure.http.middlewares=traefik-traefik-forward-auth",
							"--certificatesresolvers.letsencrypt.acme.email=iam@defn.sh",
							"--certificatesresolvers.letsencrypt.acme.storage=/data/acme/acme.json",
							"--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
							"--certificatesResolvers.letsencrypt.acme.dnschallenge=true",
							"--certificatesResolvers.letsencrypt.acme.dnschallenge.provider=cloudflare",
							"--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=108.162.193.160:53",
				]
				ports: web: redirectTo: "websecure"
				env: [{
					name: "CF_DNS_API_TOKEN"
					valueFrom: secretKeyRef: {
						name: "cloudflare"
						key:  "dns-token"
					}
				}]
			}
			relay: values: _commonConfig & {
				additionalArguments: _commonAdditionalArguments
				ports: websecure: expose: false
			}
		}
	}
	"katt-traefik-forward-auth": {
		chart_repo:    "https://k8s-at-home.com/charts"
		chart_name:    "traefik-forward-auth"
		chart_version: "1.0.10"
		install:       "traefik-forward-auth"
		namespace:     "traefik"
	}
	"katt-kuma": {
		chart_repo:    "https://kumahq.github.io/charts"
		chart_name:    "kuma"
		chart_version: "0.7.1"
		install:       "kuma"
		namespace:     "kuma-system"
		variants: {
			global: values: {
				controlPlane: mode: "global"
			}
			zone: values: {
				controlPlane: {
					mode:             "zone"
					zone:             "TODO"
					kdsGlobalAddress: "grpcs://100.100.100.100:5685"
				}
				ingress: enabled: true
			}
		}
	}
	"katt-cilium": {
		chart_repo:    "https://helm.cilium.io"
		chart_name:    "cilium"
		chart_version: "1.11.0-rc2"
		install:       "cilium"
		namespace:     "kube-system"
		variants: base: values: {
			hubble: {
				ui: enabled:    true
				relay: enabled: true
			}
			operator: replicas:    1
			hostServices: enabled: false
			bpf: masquerade:       false
		}
	}
	"katt-metacontroller": {
		version:            "2.0.12"
		upstream_kustomize: "https://github.com/metacontroller/metacontroller/manifests/production?ref=v\(version)"
	}
	"katt-pihole": {
		chart_repo:    "https://mojo2600.github.io/pihole-kubernetes"
		chart_name:    "pihole"
		chart_version: "2.4.2"
		install:       "pihole"
		namespace:     "pihole"
		variants:
			base:
				values: {
					serviceDhcp: enabled: false
					DNS1: "127.0.0.1#5353"
					DNS2: "127.0.0.1#5353"
					adlists: [
						"https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
						"https://raw.githubusercontent.com/mhhakim/pihole-blocklist/master/porn.txt",
					]
				}
	}
}

repos: [string]: upstream_manifest:  string | *""
repos: [string]: upstream_kustomize: string | *""
repos: [string]: chart_repo:         string | *""
repos: [string]: variants:           {...} | *{}
repos: [string]: variants: [string]: valus: {...} | *{}
