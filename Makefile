rewrite:
	git grep '"k8s.io/' k8s.io | cut -d: -f1 | uniq | while read -r f; do perl -pe 's{"k8s.io/}{"github.com/defn/boot/k8s.io/}' -i $$f; done

get:
	go get k8s.io/api/core/v1
	go get k8s.io/api/apps/v1
	cue get go k8s.io/api/core/v1
	cue get go k8s.io/api/apps/v1
	rsync -ia cue.mod/gen/k8s.io .
	rm -rf cue.mod/gen/k8s.io