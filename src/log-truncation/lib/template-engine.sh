#!/usr/bin/env bash
# Simple template engine using {{VAR}} substitution from exported env vars.

_substitute_template_file() {
    local template_file="$1"
    local output_file="$2"
    local line before var after

    : > "$output_file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Resolve all placeholders on the current line.
        while [[ "$line" =~ ^(.*)\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}(.*)$ ]]; do
            before="${BASH_REMATCH[1]}"
            var="${BASH_REMATCH[2]}"
            after="${BASH_REMATCH[3]}"
            line="${before}${!var-}${after}"
        done
        printf '%s\n' "$line" >> "$output_file"
    done < "$template_file"
}

render_template() {
    local template_file="$1"
    local output_file="$2"

    if [[ ! -f "$template_file" ]]; then
        error "Template not found: $template_file"
        return 1
    fi

    _substitute_template_file "$template_file" "$output_file"
}

# Backward-compatible alias retained for callers.
render_template_pure() {
    render_template "$1" "$2"
}
