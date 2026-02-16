default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')
draw := absolute_path('draw')

# parse build.yaml and filter targets by expression
_parse_targets $expr:
    #!/usr/bin/env bash
    attrs="[.board, .shield, .snippet, .\"artifact-name\"]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" build.yaml | grep -v "^," | grep -i "${expr/#all/.*}")"

# build firmware for single board & shield combination
_build_single $board $shield $snippet $artifact *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board}}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# build firmware for matching targets
build expr *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet artifact; do
        echo "targets $targets"
        just _build_single "$board" "$shield" "$snippet" "$artifact" {{ west_args }}
    done

# clear build cache and artifacts
clean:
    rm -rf {{ build }} {{ out }}

# clear all automatically generated files
clean-all: clean
    rm -rf .west zmk

# clear nix cache
clean-nix:
    nix-collect-garbage --delete-old

corne:
    @just build corne
    @just draw

# parse & plot keymap
draw:
    #!/usr/bin/env bash
    set -euo pipefail
    keymap -d -c "{{ draw }}/config.yaml" parse -z "{{ config }}/base.keymap" >"{{ draw }}/base.yaml"
    # cp "{{ draw }}/base.yaml" "{{ draw }}/base.yaml.bak"
    # keymap -d -c "draw/config.yaml" parse -z "config/base.keymap" > "draw/base.yaml"
    # yq -Yi '.layers |= map(select(.l != "Qwerty"))' "{{ draw }}/base.yaml"

    # Map all combos to ONLY Base layer
    # yq -Yi '.combos.[].l = ["Base"]' "{{ draw }}/base.yaml"


    # If any combos are mapped to Base layer, map them to ONLY Base layer
    # this allows Mirror combos to be separate
    yq -Yi '.combos[].l |= (if contains(["Base"]) then ["Base"] else . end)' "{{ draw }}/base.yaml"

    # Delete combos that are mapped to Oneshot layer
    yq -Yi 'del(.combos[] | select(.l | contains(["Oneshot"])))' "{{ draw }}/base.yaml"

    # NOTE: if a combo exists in a layer that is deleted below, it will throw an error
    yq -Yi 'del(.layers.Qwerty)' "{{ draw }}/base.yaml"
    yq -Yi 'del(.layers.Oneshot)' "{{ draw }}/base.yaml"
    yq -Yi 'del(.layers.Snake)' "{{ draw }}/base.yaml"
    # yq -Yi 'del(.layers.Mirror)' "{{ draw }}/base.yaml"
    yq -Yi 'del(.layers.LeftShift)' "{{ draw }}/base.yaml"
    yq -Yi 'del(.layers.NoIdle)' "{{ draw }}/base.yaml"
    yq -Yi 'del(.layers.Sentence)' "{{ draw }}/base.yaml"

    # yq -Yi '.combos.[].l = ["Combos"]' "{{ draw }}/base.yaml"
    keymap -c "{{ draw }}/config.yaml" draw "{{ draw }}/base.yaml" -k "corne_rotated" >"{{ draw }}/base.svg"

    # keymap -d -c "{{ draw }}/config.yaml" parse -z "{{ config }}/base.keymap.original" --virtual-layers Combos >"{{ draw }}/base.yaml"
    # yq -Yi '.combos.[].l = ["Combos"]' "{{ draw }}/base.yaml"
    # keymap -c "{{ draw }}/config.yaml" draw "{{ draw }}/base.yaml" -k "ferris/sweep" >"{{ draw }}/base.svg"

    cp "{{ draw }}/base.svg" ~/dotfiles/.config/keyboard/keyboard-layout.svg

# initialize west
init:
    west init -l config
    west update --fetch-opt=--filter=blob:none
    west zephyr-export

# list build targets
list:
    @just _parse_targets all | sed 's/,*$//' | sort | column

# update west
update:
    west update --fetch-opt=--filter=blob:none

# upgrade zephyr-sdk and python dependencies
upgrade-sdk:
    nix flake update --flake .

[no-cd]
test $testpath *FLAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    testcase=$(basename "$testpath")
    build_dir="{{ build / "tests" / '$testcase' }}"
    config_dir="{{ '$(pwd)' / '$testpath' }}"
    cd {{ justfile_directory() }}

    if [[ "{{ FLAGS }}" != *"--no-build"* ]]; then
        echo "Running $testcase..."
        rm -rf "$build_dir"
        west build -s zmk/app -d "$build_dir" -b native_posix_64 -- \
            -DCONFIG_ASSERT=y -DZMK_CONFIG="$config_dir"
    fi

    ${build_dir}/zephyr/zmk.exe | sed -e "s/.*> //" |
        tee ${build_dir}/keycode_events.full.log |
        sed -n -f ${config_dir}/events.patterns > ${build_dir}/keycode_events.log
    if [[ "{{ FLAGS }}" == *"--verbose"* ]]; then
        cat ${build_dir}/keycode_events.log
    fi

    if [[ "{{ FLAGS }}" == *"--auto-accept"* ]]; then
        cp ${build_dir}/keycode_events.log ${config_dir}/keycode_events.snapshot
    fi
    diff -auZ ${config_dir}/keycode_events.snapshot ${build_dir}/keycode_events.log
