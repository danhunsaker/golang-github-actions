FROM golang:latest

ENV GO111MODULE=on

# installing go packages with `go get` is going to be removed soon, so we `go install <package>@latest` for each instead, since `go install` doesn't
# support multiple modules at once.
RUN apt-get update && \
	apt-get -y install jq && \
	go install github.com/kisielk/errcheck@latest && \
	go install golang.org/x/tools/cmd/goimports@latest && \
	go install golang.org/x/lint/golint@latest && \
	go install github.com/securego/gosec/cmd/gosec@latest && \
	go install golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow@latest && \
	go install honnef.co/go/tools/cmd/staticcheck@latest && \
	go install github.com/client9/misspell/cmd/misspell@latest && \
	go install github.com/gordonklaus/ineffassign@latest && \
	go install github.com/fzipp/gocyclo/cmd/gocyclo@latest

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
