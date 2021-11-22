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
	"katt-traefik": {
		chart_repo:    "https://helm.traefik.io/traefik"
		chart_name:    "traefik"
		chart_version: "10.6.0"
		install:       "traefik"
		namespace:     "traefik"
		values: {
			additionalArguments: [
				"--entrypoints.websecure.http.middlewares=traefik-traefik-forward-auth",
				"--providers.kubernetescrd.allowexternalnameservices=true",
				"--providers.kubernetescrd.allowCrossNamespace=false",
				"--log.level=DEBUG",
				"--accesslog=true",
				"--serverstransport.insecureskipverify=true",
				"--global.sendanonymoususage=false",
				"--certificatesresolvers.letsencrypt.acme.email=iam@defn.sh",
				"--certificatesresolvers.letsencrypt.acme.storage=/data/acme/acme.json",
				"--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
				"--certificatesResolvers.letsencrypt.acme.dnschallenge=true",
				"--certificatesResolvers.letsencrypt.acme.dnschallenge.provider=cloudflare",
				"--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=108.162.193.160:53",
			]
			ports: web: redirectTo:           "websecure"
			ingressRoute: dashboard: enabled: false
			env: [{
				name: "CF_DNS_API_TOKEN"
				valueFrom: secretKeyRef: {
					name: "cloudflare"
					key:  "dns-token"
				}
			}]
		}
		values_relay: {
			additionalArguments: [
				"--providers.kubernetescrd.allowexternalnameservices=true",
				"--providers.kubernetescrd.allowCrossNamespace=false",
				"--log.level=DEBUG",
				"--accesslog=true",
				"--serverstransport.insecureskipverify=true",
				"--global.sendanonymoususage=false",
			]

			ingressRoute: dashboard: enabled: false

			ports: {
				traefik: port:     9200
				websecure: expose: false
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
repos: [string]: values:            {...} | *{}
