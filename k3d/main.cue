package k3d

#K3DConfig: {
	k3d_name: string
	k3d_host: string
	k3d_ip: string
	k3d_image : string | *"rancher/k3s:v1.22.6-k3s1"
	k3d_ports: [...string] | *[]

	output: {
		apiVersion: "k3d.io/v1alpha4"
		kind:       "Simple"
		metadata: name: k3d_name
		servers: 1
		agents:  0
		kubeAPI: {
			host:   k3d_host
			hostIP: "0.0.0.0"
		}
		image: k3d_image
		hostAliases: [{
			ip: k3d_ip
			hostnames: [
				"this",
			]
		}]
		volumes: [{
			volume: "/var/run/docker.sock:/var/run/docker.sock"
			nodeFilters: [
				"server:0",
			]
		}, {
			volume: "k3d-password-store:/mnt/password-store"
			nodeFilters: [
				"server:0",
			]
		}, {
			volume: "k3d-work:/mnt/work"
			nodeFilters: [
				"server:0",
			]
		}]
		options: {
			k3d: {
				wait:                true
				timeout:             "360s"
				disableLoadbalancer: false
			}
			k3s: extraArgs: [{
				arg: "--tls-san=\(k3d_ip)"
				nodeFilters: [
					"server:0",
				]
			}, {
				arg: "--tls-san=\(k3d_host)"
				nodeFilters: [
					"server:0",
				]
			}, {
				arg: "--disable=traefik"
				nodeFilters: [
					"server:0",
				]
			}]
			kubeconfig: {
				updateDefaultKubeconfig: true
				switchCurrentContext:    false
			}
		}
		registries: use: ["k3d-registry.localhost:5555"]

		if len(k3d_ports) > 0 {
			ports: [
				for p in k3d_ports {
					port: p
					nodeFilters: [ "loadbalancer" ]
				}
			]
		}
	}
}
