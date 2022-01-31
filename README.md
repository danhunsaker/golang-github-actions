# Golang GitHub Actions
Static code analysis checker for golang. If there's an error, it also sends comments back to the current pull request (or the current commit if the
action's trigger wasn't a PR).

## Inputs
A quick summary of the values you can give using `with`.

### run (required)
Execute comma-separated command(s). Valid options are any combination of `cyclo`, `errcheck`, `fmt`, `imports`, `ineffassign`, `lint`, `misspell`,
`sec`, `shadow`, `staticcheck`, and `vet`, or the shorthand option `all`. See below for more details.

### directory (default: `.`)
The directory to run the check(s) within. Useful for monorepos to check subdirectories rather than the entire repository.

### comment (default: `true`)
If set to `true` (the default), a comment will be sent to the PR/commit that triggered the action whenever a check fails. If you prefer to check the
action logs, go ahead and turn this off.

### token (default: empty)
GitHub token (use `${{ secrets.GITHUB_TOKEN }}` for this, since it's automatically provided for you). This is required when `comment` is `true` (so,
by default).

### flags (default: empty)
Add flags to pass to the check commands. **Be careful with this option if you're running multiple checks, since these flags will be passed to _every_
check command.**

### ignore-defer (default: `false`)
By default, `errcheck` marks `defer` statements as problems. Of course, sometimes (usually?) you _want_ to `defer` certain logic, say for cleaning up
resources that Go can't/won't clean automatically. Simply set this to `true` to ignore this error as a false positive.

### max-complexity (default: `15`)
The highest cyclomatic complexity to consider "ok" with the `cyclo` check. The default of 15 was chosen to match [Go Report
Card](https://goreportcard.com/)'s grading value.

### exclude (default: empty)
A list (comma-separated) of packages/paths to exclude from checks that support excludes. At the moment, that's just `cyclo` and `errcheck`. We're
exploring mechanisms for extending this to the other checks, too, but this will take some time to implement correctly.

### go-private-mod-username (default: empty)
Login username for getting Go dependencies from private repos.

### go-private-mod-password (default: empty)
Password (or GitHub personal access token) for getting Go dependencies from private repos.

### go-private-mod-org-path (default: empty)
Private organization URL, eg. `github.com/my-org`, for getting Go dependencies from private repos.


## More info about checks you can `run`

### all
Runs all the checks below in a semi-sane order. Internally, it just translates `all` to
`misspell,fmt,vet,cyclo,imports,ineffassign,errcheck,sec,shadow,staticcheck,lint` - you can take advantage of this to leave certain checks out, or to
change the order they run in. (I personally recommend dropping `lint`, since it's deprecated anyway...)

Keep in mind that this doesn't fail-fast, so all the listed checks will be run even if one fails.

Also keep in mind that you'll get one comment on your PR/commit for each check that fails, which can add up a bit if your code fails more than one
consistently. This is currently considered a feature rather than a bug, though, for two reasons. First, it's extra incentive to correct the code!
Second, GitHub enforces a comment-length limit that might prevent your combined error comment from posting, which gets frustrating quickly when you're
trying to avoid scouring logs.

### fmt
Runs `gofmt` (not to be confused with `go fmt`, which has fewer options) (and comments back on error).

<img src="./assets/fmt.png" alt="Fmt Action" width="80%" />

### vet
Runs `go vet` (and comments back on error).

### shadow
Runs `go vet --vettool=$(which shadow)` (and comments back on error).  

See [golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow](https://godoc.org/golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow) for more info.

### imports
Runs `goimports` (and comments back on error).  

See [golang.org/x/tools/cmd/goimports](https://godoc.org/golang.org/x/tools/cmd/goimports) for more info.

<img src="./assets/imports.png" alt="Imports Action" width="80%" />

### lint
**DEPRECATED** 

Runs `golint` (and comments back on error).

See [golang.org/x/lint/golint](https://github.com/golang/lint) for more info.

<img src="./assets/lint.png" alt="Lint Action" width="80%" />

### staticcheck
Runs `staticcheck` (and comments back on error).  

See [honnef.co/go/tools/cmd/staticcheck](https://staticcheck.io/) for more info.

<img src="./assets/staticcheck.png" alt="Staticcheck Action" width="80%" />

### errcheck
Runs `errcheck` (and comments back on error).  

See [github.com/kisielk/errcheck](https://github.com/kisielk/errcheck) for more info.

<img src="./assets/errcheck.png" alt="Errcheck Action" width="80%" />

### sec
Runs `gosec` (and comments back on error).  

See [github.com/securego/gosec/cmd/gosec](https://github.com/securego/gosec) for more info.

<img src="./assets/sec.png" alt="Sec Action" width="80%" />

### ineffassign
Runs `ineffassign` (and comments back on error).

See [github.com/gordonklaus/ineffassign](https://github.com/gordonklaus/ineffassign) for more info.

### misspell
Runs `misspell` (and comments back on error).

See [github.com/client9/misspell/cmd/misspell](https://github.com/client9/misspell) for more info.

### cyclo
Runs `gocyclo` (and comments back on error).

See [github.com/fzipp/gocyclo/cmd/gocyclo](https://github.com/fzipp/gocyclo) for more info.

## Sample Workflow

`.github/workflows/static.yml`

```yaml
name: static check
on: pull_request

jobs:
  imports:
    name: Imports
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: imports
        token: ${{ secrets.GITHUB_TOKEN }}

  errcheck:
    name: Errcheck
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: errcheck
        token: ${{ secrets.GITHUB_TOKEN }}

  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: lint
        token: ${{ secrets.GITHUB_TOKEN }}

  shadow:
    name: Shadow
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: shadow
        token: ${{ secrets.GITHUB_TOKEN }}

  staticcheck:
    name: StaticCheck
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: staticcheck
        token: ${{ secrets.GITHUB_TOKEN }}

  sec:
    name: Sec
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: check
      uses: grandcolline/golang-github-actions@v1.1.0
      with:
        run: sec
        token: ${{ secrets.GITHUB_TOKEN }}
        flags: "-exclude=G104"
```
