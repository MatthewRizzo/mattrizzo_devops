#!/usr/bin/env bash
# Script to create a markdown-compatible table of contents for ALL markdown
# files in the recrusive file structure from which it is run.
# Smart enough to know some files are linked to the .md files found.

declare -a output_result=""

# Return 1 if is dir. 0 if is NOT dir.
function is_file_dir() {
    local -r file_name="$1"
    if [[ $(echo "${file_name: -1}") == "/" ]]; then
        return 1
    else
        return 0
    fi
}

function main() {

    files=$(find . -name "*.md" | tree -F | head -n -1)

    formatted_tree=$(echo "$files" \
            | sed -e 's/├/ /g; s/└/ /g; s/│/ /g; s/── / * /g;' \
            | sed -e 's/^.\{2\}//g' \
            | tail -n +2 \
            | sed 's/[*]$//' \
    )
    file_list="$(find . -name "*.md" \
            | tree -F -i \
            | head -n -1 \
            | tail -n +2 \
            | cat
    )"

    output_result="$formatted_tree"

    local is_file_dir=0

    local default_IFS="$IFS"
    local IFS=$'\n'
    for current_file in $file_list; do
        file_path=""
        markdown_file_path=""

        is_file_dir "$current_file"
        is_file_dir_res="$?"

        if [[ $is_file_dir_res -eq 1 ]]; then
            formatted_dir_name="${current_file::-1}"
            file_path="$(find . -type d -name  "${formatted_dir_name}")"
            markdown_file_path="[$formatted_dir_name](${file_path})"
        else
            file_path="$(find . -name "$current_file" | head -n 1)"
            # echo -e "raw file_path = $file_path"
            markdown_file_path="[$current_file]($file_path)"
        fi

        # Escape any '/' with '\' for sed
        escaped_file_path="$(echo "$markdown_file_path" | sed 's/[]\/$*^[]/\\&/g')"
        escaped_current_file="$(echo "$current_file" | sed 's/[]\/$*^[]/\\&/g')"


        output_result="$(echo -e "$output_result" | sed "s/* $escaped_current_file/\* $escaped_file_path/")"
    done

    echo "$output_result" | cat
}

main "$@"
