package boot

import "tool/exec"

import "tool/file"

command: boot: {
	for rname, r in repos {
		"upstream-curl-\(rname)": exec.Run & {
			cmd: ["curl", "-sSL", r.upstream_manifest]
			stdout: string
		}
		"upstream-write-\(rname)": file.Create & {
			filename: "../\(rname)/upstream/main.yaml"
			contents: boot["upstream-curl-\(rname)"].stdout
		}
		"base-kustomize-\(rname)": exec.Run & {
			cmd: ["kustomize", "build", "../\(rname)/base"]
			stdout: string
			after:  "upstream-write-\(rname)"
		}
		"base-write\(rname)": file.Create & {
			filename: "../\(rname)/main.yaml"
			contents: boot["base-kustomize-\(rname)"].stdout
		}
	}
}
