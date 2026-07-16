#!/usr/bin/env bash
# core/runner.sh — runs a profile's ordered list of steps.
#
# A profile (profiles/<name>/profile.sh) describes what to install and in what
# order by calling step() for each step. The runner then walks that list: it
# prints a clear heading for each step, optionally asks before running it, runs
# it, and prints a summary at the end. This is the single place that knows how
# to "run the install", shared by every platform.
#
# A step's run-target is either a shell function name or a script path relative
# to the profile directory. Scripts run in a fresh bash with ARCHE exported.

# Parallel arrays hold the registered steps (bash 3.2 safe, no maps).
STEP_ID=()
STEP_RUN=()
STEP_REBOOT=()
STEP_DESC=()

# Register one step. Called from a profile's profile_steps function.
#   step <id> <run-target> <reboot|-> <description...>
step() {
    local id="$1" run="$2" reboot="$3"; shift 3
    STEP_ID+=("$id")
    STEP_RUN+=("$run")
    STEP_REBOOT+=("$reboot")
    STEP_DESC+=("$*")
}

# Ask a yes / no / all question. Returns 0 for yes, 1 for no. Sets _RUN_ALL=1
# on "all" so the caller stops asking. Honors ARCHE_YES=1 (non-interactive).
_RUN_ALL=0
_ask_run() {
    [[ "${ARCHE_YES:-0}" == "1" || "$_RUN_ALL" == "1" ]] && return 0
    local reply
    printf "  Run this step? [y = yes, n = skip, a = yes to all] "
    read -r reply
    case "$reply" in
        [aA]) _RUN_ALL=1; return 0 ;;
        [yY]) return 0 ;;
        *)    return 1 ;;
    esac
}

# Execute one run-target (function name or profile-relative script path).
_run_target() {
    local run="$1" profile_dir="$2"
    if [[ "$(type -t "$run" 2>/dev/null)" == "function" ]]; then
        "$run"
    elif [[ -f "$profile_dir/$run" ]]; then
        bash "$profile_dir/$run"
    elif [[ -f "$run" ]]; then
        bash "$run"
    else
        log_err "Step target not found: $run"
        return 1
    fi
}

# Run the whole profile. The profile file must already be sourced (so step()
# has populated the arrays) and must set PROFILE_DIR + PROFILE_NAME.
#   run_profile
run_profile() {
    local profile_dir="${PROFILE_DIR:?run_profile: PROFILE_DIR not set}"
    local total=${#STEP_ID[@]}
    local i id run reboot desc rc
    RESULTS_ID=(); RESULTS_STATUS=()

    log_step "Installing the ${PROFILE_NAME:-arche} setup (${total} steps)"
    if [[ "${ARCHE_YES:-0}" == "1" ]]; then
        log_info "Running every step without asking (you passed --yes)"
    else
        log_info "You will be asked before each step. Answer 'a' to run the rest without asking."
    fi

    for (( i = 0; i < total; i++ )); do
        id="${STEP_ID[$i]}"
        run="${STEP_RUN[$i]}"
        reboot="${STEP_REBOOT[$i]}"
        desc="${STEP_DESC[$i]}"

        # Honor --only / --from filters if set.
        if [[ -n "${ARCHE_ONLY:-}" && "$id" != "$ARCHE_ONLY" ]]; then
            continue
        fi

        echo
        log_step "Step $(( i + 1 )) of ${total}: ${id}"
        [[ -n "$desc" ]] && log_info "$desc"
        echo

        if ! _ask_run; then
            log_warn "Skipped: $id"
            RESULTS_ID+=("$id"); RESULTS_STATUS+=("skipped")
            continue
        fi

        rc=0
        _run_target "$run" "$profile_dir" || rc=$?

        if [[ $rc -eq 0 ]]; then
            RESULTS_ID+=("$id"); RESULTS_STATUS+=("done")
        elif [[ $rc -eq 2 && "$reboot" == "reboot" ]]; then
            # Step asked for a reboot before continuing (e.g. kernel upgrade).
            RESULTS_ID+=("$id"); RESULTS_STATUS+=("done (reboot needed)")
            echo
            log_warn "This step needs a reboot before the rest can continue."
            log_warn "Reboot, then run the installer again. It will pick up where it left off."
            _prompt_reboot
            _print_summary
            return 0
        else
            RESULTS_ID+=("$id"); RESULTS_STATUS+=("failed")
            log_err "Step '$id' did not finish. Moving on to the next one."
        fi
    done

    _print_summary
    # Non-zero exit if anything failed, so callers/CI notice.
    local s
    for s in "${RESULTS_STATUS[@]}"; do [[ "$s" == "failed" ]] && return 1; done
    return 0
}

_prompt_reboot() {
    [[ "${ARCHE_YES:-0}" == "1" ]] && { log_info "Skipping the reboot prompt (non-interactive)."; return 0; }
    local reply
    printf "  Reboot now? [y/N] "
    read -r reply
    if [[ "$reply" =~ ^[yY]$ ]]; then
        log_info "Rebooting"
        sudo systemctl reboot 2>/dev/null || sudo reboot
    else
        log_info "No problem. Reboot when you are ready, then run the installer again."
    fi
}

# Print the end-of-run summary. Takes the names of the two result arrays.
_print_summary() {
    echo
    log_step "Summary"
    local i
    for (( i = 0; i < ${#RESULTS_ID[@]}; i++ )); do
        case "${RESULTS_STATUS[$i]}" in
            done*)    printf '  \033[1;32m%-8s\033[0m %s\n' "done"    "${RESULTS_ID[$i]}" ;;
            failed)   printf '  \033[1;31m%-8s\033[0m %s\n' "failed"  "${RESULTS_ID[$i]}" ;;
            skipped)  printf '  \033[1;33m%-8s\033[0m %s\n' "skipped" "${RESULTS_ID[$i]}" ;;
        esac
    done
    echo
}
