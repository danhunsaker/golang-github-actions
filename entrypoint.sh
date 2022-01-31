#!/bin/sh
set -e

# ------------------------
#  Environments
# ------------------------
self=${0}
RUN=${1}
WORKING_DIR=${2}
SEND_COMMENT=${3}
GITHUB_TOKEN=${4}
FLAGS=${5}
IGNORE_DEFER_ERR=${6}
MAX_COMPLEXITY=${7}
GO_PRIVATE_MOD_USERNAME=${8}
GO_PRIVATE_MOD_PASSWORD=${9}
GO_PRIVATE_MOD_ORG_PATH=${10}

SUBMODULE_NAME=$(echo ${WORKING_DIR} | sed 's#\./##g')
MODULE_NAME=$(echo "github.com/${GITHUB_REPOSITORY}/${SUBMODULE_NAME}" | sed 's#/\.?$##')

COMMENT=""
SUCCESS=0


# ------------------------
#  Functions
# ------------------------
# send_comment is send ${comment} to pull request.
# this function use ${GITHUB_TOKEN}, ${COMMENT} and ${GITHUB_EVENT_PATH}
send_comment() {
	PAYLOAD=$(echo '{}' | jq --arg body "${COMMENT}" '.body = $body')
	if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
		COMMENTS_URL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
	else
		SHA=$(cat ${GITHUB_EVENT_PATH} | jq -r .commits[0].id)
		COMMENTS_URL=$(echo "$(cat ${GITHUB_EVENT_PATH} | jq -r .repository.commits_url)/comments" | sed -n 's#\{/sha\}#/'${SHA}'#p')
	fi
	curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data "${PAYLOAD}" "${COMMENTS_URL}" > /dev/null
}

setup_private_repo_access() {
	# setup access to go private modules via .netrc file
	if [ "${GO_PRIVATE_MOD_ORG_PATH}" != "" ]; then
		cat << EOF > .netrc
machine $(echo ${GO_PRIVATE_MOD_ORG_PATH} | sed 's#/.*##')
  login ${GO_PRIVATE_MOD_USERNAME}
  password ${GO_PRIVATE_MOD_PASSWORD}
EOF

		git config --global "url.https://${GO_PRIVATE_MOD_USERNAME}:${GO_PRIVATE_MOD_PASSWORD}@${GO_PRIVATE_MOD_ORG_PATH}/.insteadOf" https://${GO_PRIVATE_MOD_ORG_PATH}/

		go env -w GOPRIVATE="${GO_PRIVATE_MOD_ORG_PATH}"
		# check result status and report back
		if [ $? != 0 ]; then
				printf "\t\033[31mSetup go private repos for: ${GO_PRIVATE_MOD_ORG_PATH} \033[0m \033[0;30m\033[41mFAILURE!\033[0m\n"
		else
				printf "\t\033[32mSetup go private repos for: ${GO_PRIVATE_MOD_ORG_PATH} \033[0m \033[0;30m\033[42mpass\033[0m\n"
		fi
	fi
}

# mod_download is getting go modules using go.mod.
mod_download() {
	if [ ! -e go.mod ]; then go mod init ${MODULE_NAME}; fi
	go mod download
	if [ $? -ne 0 ]; then exit 1; fi
}

# check_cyclo executes gocyclo and generate ${COMMENT} and ${SUCCESS}
check_cyclo() {
	set +e
	OUTPUT=$(sh -c "gocyclo -over ${MAX_COMPLEXITY} -avg -total ${FLAGS} . $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ gocyclo failed (${SUBMODULE_NAME})
$(echo "${OUTPUT}" | head -n-2 | wc -l) function(s) exceeding a complexity of ${MAX_COMPLEXITY}
<details><summary>Show Detail</summary>

\`\`\`
${OUTPUT}
\`\`\`
</details>
"
}

# check_errcheck executes "errcheck" and generate ${COMMENT} and ${SUCCESS}
check_errcheck() {
	if [ "${IGNORE_DEFER_ERR}" = "true" ]; then
		IGNORE_COMMAND="| grep -v defer"
	fi

	set +e
	OUTPUT=$(sh -c "errcheck ${FLAGS} ./... $* ${IGNORE_COMMAND}" 2>&1)
	test -z "${OUTPUT}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ errcheck failed (${SUBMODULE_NAME})
\`\`\`
${OUTPUT}
\`\`\`
"
}

# check_fmt executes "go fmt" and generate ${COMMENT} and ${SUCCESS}
check_fmt() {
	set +e
	UNFMT_FILES=$(sh -c "gofmt -l -s . $*" 2>&1)
	test -z "${UNFMT_FILES}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	FMT_OUTPUT=""
	for file in ${UNFMT_FILES}; do
		FILE_DIFF=$(gofmt -d -e "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
		FMT_OUTPUT="${FMT_OUTPUT}
<details><summary><code>${file}</code></summary>

\`\`\`diff
${FILE_DIFF}
\`\`\`
</details>

"
	done
	COMMENT="## ⚠ gofmt failed (${SUBMODULE_NAME})
${FMT_OUTPUT}
"
}

# check_imports executes go imports and generate ${COMMENT} and ${SUCCESS}
check_imports() {
	set +e
	UNFMT_FILES=$(sh -c "goimports -l . $*" 2>&1)
	test -z "${UNFMT_FILES}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	FMT_OUTPUT=""
	for file in ${UNFMT_FILES}; do
		FILE_DIFF=$(goimports -d -e "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
		FMT_OUTPUT="${FMT_OUTPUT}
<details><summary><code>${file}</code></summary>

\`\`\`diff
${FILE_DIFF}
\`\`\`
</details>

"
	done
	COMMENT="## ⚠ goimports failed (${SUBMODULE_NAME})
${FMT_OUTPUT}
"
}

# check_ineffassign executes "ineffassign" and generate ${COMMENT} and ${SUCCESS}
check_ineffassign() {
	set +e
	OUTPUT=$(sh -c "ineffassign ./... $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ ineffassign failed
\`\`\`
${OUTPUT}
\`\`\`
"
}

# check_lint executes golint and generate ${COMMENT} and ${SUCCESS}
check_lint() {
	set +e
	OUTPUT=$(sh -c "golint -set_exit_status ./... $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ golint failed (${SUBMODULE_NAME})
$(echo "${OUTPUT}" | awk 'END{print}')
<details><summary>Show Detail</summary>

\`\`\`
$(echo "${OUTPUT}" | sed -e '$d')
\`\`\`
</details>
"
}

# check_misspelling executes "misspell" and generate ${COMMENT} and ${SUCCESS}
check_misspelling() {
	set +e
	OUTPUT=$(sh -c "misspell ${FLAGS} -error . $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ misspell failed
\`\`\`
${OUTPUT}
\`\`\`
"
}

# check_sec executes gosec and generate ${COMMENT} and ${SUCCESS}
check_sec() {
	set +e
	gosec -quiet ${FLAGS} ./... > result.txt 2>&1
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ gosec failed (${SUBMODULE_NAME})
\`\`\`
$(tail -n 6 result.txt)
\`\`\`
<details><summary>Show Detail</summary>

\`\`\`
$(cat result.txt)
\`\`\`
[Code Reference](https://github.com/securego/gosec#available-rules)

</details>
"

	rm result.txt
}

# check_shadow executes "go vet -vettool=/go/bin/shadow" and generate ${COMMENT} and ${SUCCESS}
check_shadow() {
	set +e
	OUTPUT=$(sh -c "go vet -vettool=$(which shadow) ${FLAGS} ./... $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ shadow failed (${SUBMODULE_NAME})
\`\`\`
${OUTPUT}
\`\`\`
"
}

# check_staticcheck executes "staticcheck" and generate ${COMMENT} and ${SUCCESS}
check_staticcheck() {
	set +e
	OUTPUT=$(sh -c "staticcheck ${FLAGS} ./... $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ staticcheck failed (${SUBMODULE_NAME})
\`\`\`
${OUTPUT}
\`\`\`

[Checks Document](https://staticcheck.io/docs/checks)
"
}

# check_vet executes "go vet" and generate ${COMMENT} and ${SUCCESS}
check_vet() {
	set +e
	OUTPUT=$(sh -c "go vet ${FLAGS} ./... $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	COMMENT="## ⚠ vet failed (${SUBMODULE_NAME})
\`\`\`
${OUTPUT}
\`\`\`
"
}


# ------------------------
#  Main Flow
# ------------------------
cd ${GITHUB_WORKSPACE}/${WORKING_DIR}

setup_private_repo_access

if [ ${RUN} = "all" ]; then
	RUN="misspell,fmt,vet,cyclo,imports,ineffassign,errcheck,sec,shadow,staticcheck,lint"
fi

case ${RUN} in
	"cyclo" )
		check_cyclo
		;;
	"errcheck" )
		mod_download
		check_errcheck
		;;
	"fmt" )
		check_fmt
		;;
	"imports" )
		check_imports
		;;
	"ineffassign" )
		mod_download
		check_ineffassign
		;;
	"lint" )
		check_lint
		;;
	"misspell" )
		mod_download
		check_misspelling
		;;
	"sec" )
		mod_download
		check_sec
		;;
	"shadow" )
		mod_download
		check_shadow
		;;
	"staticcheck" )
		mod_download
		check_staticcheck
		;;
	"vet" )
		mod_download
		check_vet
		;;
	*,* )
		set +e
		checks=$(echo ${RUN} | sed 's/,/ /g')
		for check in ${checks}; do
			COMMENT="${COMMENT}${check}: "
			"${self}" "${check}" "${WORKING_DIR}" "${SEND_COMMENT}" "${GITHUB_TOKEN}" "${FLAGS}" "${IGNORE_DEFER_ERR}" "${MAX_COMPLEXITY}" "${GO_PRIVATE_MOD_USERNAME}" "${GO_PRIVATE_MOD_PASSWORD}" "${GO_PRIVATE_MOD_ORG_PATH}"
			STATUS=$?
			if [ ${STATUS} -ne 0 ]; then
				# 0 on all success; last failed value on any failure
				SUCCESS=${STATUS}
				COMMENT="${COMMENT}fail\n"
			else
				COMMENT="${COMMENT}success!\n"
			fi
		done
		set -e
		;;
	* )
		echo "Invalid command '${RUN}'"
		exit 1
esac

if [ ${SUCCESS} -ne 0 ]; then
	echo "Check Failed!!"
	echo "${COMMENT}"
	if [ "${SEND_COMMENT}" = "true" ]; then
		send_comment
	fi
fi

exit ${SUCCESS}
