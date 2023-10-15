#!/bin/bash

set -eu

here=$(readlink -f "$0")
root_dir=$(dirname "${here}")
root_dir="${root_dir%/}"
resources_dir="${root_dir}/resources"
cache_dir="${root_dir}/cache"
output_dir="${root_dir}/output"

usage() {
    echo "Usage: /path/to/pack.sh [-j </path/to/java>] <app-id>"
}

arg_java="java"
while getopts "hj:" flag; do
    case "${flag}" in
    h)
        usage
        exit 0
        ;;
    j) arg_java="${OPTARG}" ;;
    *)
        exit 1
        ;;
    esac
done

shift $((OPTIND - 1))

if ! [ -v "1" ]; then
    usage
    exit 0
fi

app_id="$1"
echo "I: App ID: ${app_id}"

ensure_dir() {
    if ! [[ -d "$1" ]]; then
        mkdir "$1"
        echo "I: Creating '$1'"
    fi
}

gh_release_latest() {
    url="https://api.github.com/repos/$1/releases/latest"
    data=$(curl --fail -Ls "${url}")
    echo "${data}"
}

gh_download_release_asset() {
    url="https://github.com/$1/releases/download/$2/$3"
    echo "I: Downloading '${url}' into '$4'"
    curl --fail -Ls "${url}" -o "$4"
}

parse_gh_release_tagname() {
    line=$(echo "$1" | grep -m 1 "tag_name")
    tag_name=$(echo "${line}" | sed -nr "s/.*\"tag_name\": \"(.*)\".*/\1/p")
    echo "${tag_name}"
}

java_cmd="${arg_java}"
if
    ! command -v "${java_cmd}" >/dev/null
then
    echo "E: Cannot find command java at '${java_cmd}', did you install it?"
    exit 1
fi

ensure_dir "${resources_dir}"
ensure_dir "${cache_dir}"
ensure_dir "${output_dir}"

rv_patches_repo="ReVanced/revanced-patches"
rv_patches_release=$(gh_release_latest "${rv_patches_repo}")
rv_patches_version=$(parse_gh_release_tagname "${rv_patches_release}")
rv_patches_json="${resources_dir}/revanced-patches-${rv_patches_version}.json"
rv_patches_jar="${resources_dir}/revanced-patches-${rv_patches_version}.jar"

if ! [[ -f "${rv_patches_json}" ]]; then
    gh_download_release_asset \
        "${rv_patches_repo}" \
        "${rv_patches_version}" \
        "patches.json" \
        "${rv_patches_json}"
fi

if ! [[ -f "${rv_patches_jar}" ]]; then
    gh_download_release_asset \
        "${rv_patches_repo}" \
        "${rv_patches_version}" \
        "revanced-patches-${rv_patches_version#v}.jar" \
        "${rv_patches_jar}"
fi

rv_patches_compatibles=$(grep -Eo "\"name\":\"${app_id}\",\"versions\":(null|\\[[\"0-9\\.,]+\\])" "${rv_patches_json}" || true)
if [[ "${rv_patches_compatibles}" == "" ]]; then
    echo "E: No patches found for '${app_id}'"
    exit 1
fi

app_apk_name="${app_id}.apk"
rv_app_version=$(echo "${rv_patches_compatibles}" | sed -nr "s/.*\"([0-9\\.]+)\"\\]$/\1/p;q")
if [[ "${rv_app_version}" == "" ]]; then
    maybe_app_apk_name=$(cd "${resources_dir}" && find . -type f -iname "${app_id}-*.apk" | tail -n1)
    if [[ "${maybe_app_apk_name}" != "" ]]; then
        app_apk_name="${maybe_app_apk_name#.\/}"
    fi
else
    app_apk_name="${app_id}-${rv_app_version}.apk"
    echo "I: Patches require specific version '${rv_app_version}'"
fi

app_apk="${resources_dir}/${app_apk_name}"
if ! [[ -f "${app_apk}" ]]; then
    echo "E: Missing file '${app_apk}'"
    exit 1
fi

rv_integrations_repo="ReVanced/revanced-integrations"
rv_integrations_release=$(gh_release_latest "${rv_integrations_repo}")
rv_integrations_version=$(parse_gh_release_tagname "${rv_integrations_release}")
rv_integrations_apk="${resources_dir}/revanced-integrations-${rv_integrations_version}.apk"

if ! [[ -f "${rv_integrations_apk}" ]]; then
    gh_download_release_asset \
        "${rv_integrations_repo}" \
        "${rv_integrations_version}" \
        "revanced-integrations-${rv_integrations_version#v}.apk" \
        "${rv_integrations_apk}"
fi

rv_cli_repo="ReVanced/revanced-cli"
rv_cli_release=$(gh_release_latest "${rv_cli_repo}")
rv_cli_version=$(parse_gh_release_tagname "${rv_cli_release}")
rv_cli_jar="${resources_dir}/revanced-cli-${rv_cli_version}.jar"

if ! [[ -f "${rv_cli_jar}" ]]; then
    gh_download_release_asset \
        "${rv_cli_repo}" \
        "${rv_cli_version}" \
        "revanced-cli-${rv_cli_version#v}-all.jar" \
        "${rv_cli_jar}"
fi

rv_app_apk_name="revanced-${app_apk_name}"
rv_app_apk="${output_dir}/${rv_app_apk_name}"
echo "I: Patching '${app_apk}' into '${rv_app_apk}'"

(
    cd "${cache_dir}"
    "${java_cmd}" \
        -jar "${rv_cli_jar}" \
        patch \
        --include "Custom branding" \
        --patch-bundle "${rv_patches_jar}" \
        --merge "${rv_integrations_apk}" \
        --out "${rv_app_apk}" \
        "${app_apk}"
)

echo "I: Success!"
