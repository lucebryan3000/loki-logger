#!/usr/bin/env bash
# Simple template engine using envsubst-style substitution

render_template() {
    local template_file="$1"
    local output_file="$2"

    if [[ ! -f "$template_file" ]]; then
        error "Template not found: $template_file"
        return 1
    fi

    # Use envsubst to replace {{VAR}} with $VAR values
    # First convert {{VAR}} to ${VAR} format
    local processed
    processed=$(sed 's/{{/\${/g; s/}}/}/g' "$template_file")

    # Then use bash eval to substitute
    # Note: set -euo pipefail provides some protection against malformed values
    eval "cat <<EOF
$processed
EOF
" > "$output_file"
}

# Alternative: Pure bash substitution (no external tools)
render_template_pure() {
    local template_file="$1"
    local output_file="$2"
    local template_content

    template_content=$(<"$template_file")

    # Replace {{VAR}} with ${VAR} and evaluate
    template_content="${template_content//\{\{/\$\{}"
    template_content="${template_content//\}\}/\}}"

    eval "echo \"$template_content\"" > "$output_file"
}
