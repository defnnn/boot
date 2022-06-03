VERSION --shell-out-anywhere --use-chmod --use-host-command --earthly-version-arg --use-copy-link 0.6

IMPORT github.com/defn/cloud/lib:master AS lib

pre-commit:
    FROM registry.fly.io/defn:dev-tower
    ARG workdir
    DO lib+PRECOMMIT --workdir=${workdir}
