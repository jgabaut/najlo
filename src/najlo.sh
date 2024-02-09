#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2024  jgabaut
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# -----------------------------
# Lex a Makefile
# -----------------------------
#
# expr:=1
# %.o: %.c
#     ./build.sh
# rules: dep1 dep2 dependencies
#     this = rule_expr;
#
# -----------------------------
# Output format: In development
#
# -----------------------------
# The setting of dbg_print to 1 enables the internal logic format to be displayed.
# -----------------------------
# {RULE} -> {myrecipe}
#	 <- {DEPS} -> {} -> [#0] ->
#		{NO_DEPS}
#	 };
#	 {RULE_EXPR} -> {@echo "HELLO"}
#	 {RULE_EXPR} -> {touch $^}
# {RULE} -> {%.o}
#	 <- {DEPS} -> { %.c} -> [#1] ->
#		{INGR} - {%.c} [0],
#	 };
#	 {RULE_EXPR} -> {@echo "Transmute"}
# {EXPR} -> {.DEFAULT_GOAL := all}
# {EXPR} -> {hey = 10}
# ----------------------------
# The final recap output can be turned off by setting skip_recap to 1.
# ----------------------------
# {MAIN} -> {
#	[{EXPR_MAIN} -> {foo = 10}, [#0]],
#	[{EXPR_MAIN} -> {.DEFAULT_GOAL := all}, [#1]],
#	[{EXPR_MAIN} -> {hey = 10}, [#2]],
#}
#{RULES} -> {
#	[{RULE} [#0] -> {src/najlo.sh} <- {1707065478} <- {DEPS} -> { LICENSE} -> [#1]],
#	[{RULE} [#1] -> {src/najlo_cli.sh} <- {1706853672} <- {DEPS} -> {} -> [#0]],
#	[{RULE} [#2] -> {toot} <- {NO_TIME} <- {DEPS} -> {} -> [#0]],
#	[{RULE} [#3] -> {./anvil} <- {NO_TIME} <- {DEPS} -> { toot src/najlo.sh} -> [#2]],
#	[{RULE} [#4] -> {all} <- {NO_TIME} <- {DEPS} -> { src/najlo.sh toot} -> [#2]],
#	[{RULE} [#5] -> {%.a} <- {NO_TIME} <- {DEPS} -> { %.o} -> [#1]],
#}
#{DEPS} -> {
#	[{RULE: src/najlo.sh #0} <-- [{LICENSE} {[0], [1707065478]}, ]],
#	[{RULE: src/najlo_cli.sh #1} <-- [{NO_DEPS}]],
#	[{RULE: toot #2} <-- [{NO_DEPS}]],
#	[{RULE: ./anvil #3} <-- [{toot} {[0], [NO_TIME]}, {src/najlo.sh} {[1], [NO_TIME]}, ]],
#	[{RULE: all #4} <-- [{src/najlo.sh} {[0], [NO_TIME]}, {toot} {[1], [NO_TIME]}, ]],
#	[{RULE: %.a #5} <-- [{%.o} {[0], [NO_TIME]}, ]],
#}
#{RULE_EXPRS} -> {
#	{{RULE} [#0] -> {src/najlo.sh} <- {1707065478} <- {DEPS} -> { LICENSE} -> [#1]} --> [{RULE_EXPR #0} {@echo "HI"}, ],
#	{{RULE} [#1] -> {src/najlo_cli.sh} <- {1706853672} <- {DEPS} -> {} -> [#0]} --> [{RULE_EXPR #0} {@echo "HELLO"}, {RULE_EXPR #1} {touch $^}, ],
#	{{RULE} [#2] -> {toot} <- {NO_TIME} <- {DEPS} -> {} -> [#0]} --> [{RULE_EXPR #0} {@echo "TOOT"}, ],
#	{{RULE} [#3] -> {./anvil} <- {NO_TIME} <- {DEPS} -> { toot src/najlo.sh} -> [#2]} --> [{RULE_EXPR #0} {@echo -e "\033[1;35m[Makefile]\e[0m    Bootstrapping \"./$anvil\":"}, ],
#	{{RULE} [#4] -> {all} <- {NO_TIME} <- {DEPS} -> { src/najlo.sh toot} -> [#2]} --> [{RULE_EXPR #0} {@echo "Transmute"}, {RULE_EXPR #1} {@echo "Transmute"}, ],
#	{{RULE} [#5] -> {%.a} <- {NO_TIME} <- {DEPS} -> { %.o} -> [#1]} --> [{RULE_EXPR #0} {@echo "Transmute"}, {RULE_EXPR #1} {@echo "Transmute"}, {RULE_EXPR #2} {@echo "Transmute"}, {RULE_EXPR #3} {@echo "Transmute"}, ],
#}
# ----------------------------
#

najlo_version="0.0.4"
rule_rgx='^([[:graph:]^:]+:){1,1}([[:space:]]*[[:graph:]]*)*$'
# Define the tab character as a variable
ruleline_mark_char=$'\t'
# Build the regex with the tab character variable
ruleline_rgx="^$ruleline_mark_char"

function echo_najlo_version_short() {
  printf "%s\n" "$najlo_version"
}

function echo_najlo_version() {
  printf "najlo, v%s\n" "$najlo_version"
}

function echo_najlo_splash {
    local njl_version="$1"
    local prog="$2"
    printf "najlo, v{%s}\nCopyright (C) 2024  jgabaut\n\n  This program comes with ABSOLUTELY NO WARRANTY; for details type \`%s -W\`.\n  This is free software, and you are welcome to redistribute it\n  under certain conditions; see file \`LICENSE\` for details.\n\n  Full source is available at https://github.com/jgabaut/najlo\n\n" "$njl_version" "$prog"
}

function lex_makefile() {
    local lvl_regex='^[0-9]+$'
    local input="$1"
    [[ -f "$input" ]] || { printf "{%s} was not a valid file.\n" "$input"; exit 1 ; }
    local dbg_print="$2"
    if ! [[ "$dbg_print" =~ $lvl_regex ]] ; then {
        [[ -n "$dbg_print" ]] && printf "Invalid arg: {%s}. Using 0\n" "$2"
        dbg_print=0
    }
    fi
    local skip_recap="$3"
    if ! [[ "$skip_recap" =~ $lvl_regex ]] ; then {
        [[ -n "$skip_recap" ]] && printf "Invalid arg: {%s}. Using 0\n" "$3"
        skip_recap=0
    }
    fi
    local report_warns="$4"
    if ! [[ "$report_warns" =~ $lvl_regex ]] ; then {
        [[ -n "$report_warns" ]] && printf "Invalid arg: {%s}. Using 0\n" "$4"
        report_warns=0
    }
    fi
    local draw_progress="$5"
    if ! [[ "$draw_progress" =~ $lvl_regex ]] ; then {
        [[ -n "$draw_progress" ]] && printf "Invalid arg: {%s}. Using 0\n" "$5"
        draw_progress=0
    }
    fi

    local tot_lines="$(cut -f1 -d' ' <<< "$(wc -l "$input")")"
    local rulename=""
    local rule_ingredients=""
    local last_rulename=""
    local inside_rule=0
    local comment=""
    local line=""
    local ingrs_arr=""
    local ingr_i=0
    local rulexpr_i=0
    local rule_i=0
    local mod_time=""
    local ingr_mod_time=""
    local mainexpr_i=0
    local -a mainexpr_arr=()
    local -a rules_arr=()
    local -a ruleingrs_arr=()
    local -a rulexpr_arr=()
    local tot_warns=0
    local cur_line=0
    local PROGRESS_BAR_WIDTH=40  # Width of the progress bar

    while IFS= read -r line; do {
        #[[ ! -z "$line" ]] && printf "line: {%s}\n" "$line"
        comment="$(cut -f2 -d'#' <<< "$line")"
        line="$(cut -f1 -d'#' <<< "$line")"
        rulename="$(cut -f1 -d":" <<< "$line")"
        #rule_ingredients="$(awk -F": " '{print $2}' <<< "$line")"
        if [[ "$draw_progress" -gt 0 ]] ; then {
            cur_line="$((cur_line +1))"
            # Update progress bar
            progress=$((cur_line * 100 / tot_lines))
            filledWidth=$((progress * PROGRESS_BAR_WIDTH / 100))
            emptyWidth=$((PROGRESS_BAR_WIDTH - filledWidth))
            printf "\033[1;35m  Reading...    [" >&2
            # Draw filled portion of the progress bar
            for ((i = 0; i < filledWidth; ++i)); do
                printf "#" >&2
            done
            # Draw empty portion of the progress bar
            for ((i = 0; i < emptyWidth; ++i)); do
                printf " " >&2
            done
            printf "]    %d%%\r\e[0m" "$progress" >&2
        }
        fi

        # If the line ends with "\", collect continuation
        if [[ "$line" == *"\\" ]] ; then {
            # Line continuation found, remove trailing backslash
            echo "line: {$line}" >&2
            current_line="${line%\\}"
            echo "current_line: {$current_line}" >&2
            # Continue reading next line and append to current_line
            while IFS= read -r next_line; do {
                current_line+="${next_line%\\}"
                echo "current_line, after conjunction: {$current_line}" >&2
                if [[ "$next_line" != *"\\" ]]; then {
                    break
                }
                fi
            } done
        } else {
            # Line does not end with "\"
            current_line="$line"
        }
        fi

        rule_ingredients="$(awk -F": " '{print $2}' <<< "$current_line")"

        # Process line

        if [[ "$current_line" =~ $rule_rgx ]] ; then {
            # Line matched rule regex
            inside_rule=1
            last_rulename="$rulename"
            ingr_i=0
            rulexpr_i=0
            mod_time="$(date -r "$rulename" +%s 2>/dev/null)"
            [[ -z "$mod_time" ]] && mod_time="NO_TIME"
            [[ "$dbg_print" -gt 0 ]] && printf "{RULE} [#%s] -> {%s} <- {%s}" "$rule_i" "$rulename" "$mod_time"
            [[ "$dbg_print" -gt 0 ]] && printf "\n\t<- {DEPS} -> {%s} ->" "$rule_ingredients"
            ingrs_arr=( $rule_ingredients )
            [[ "$dbg_print" -gt 0 ]] && printf " [#%s] ->" "${#ingrs_arr[@]}"
            for ingr in "${ingrs_arr[@]}" ; do {
                #printf "\n\t[[ingr: $ingr]] - [[$rule_ingredients]]\n"
                if [[ ! -z "$ingr" ]] ; then {
                    [[ "$dbg_print" -gt 0 ]] && printf "\n\t\t{INGR} - {%s} [%s], " "$ingr" "$ingr_i"
                    ingr_mod_time="$(date -r "$ingr" +%s 2>/dev/null)"
                    [[ -z "$ingr_mod_time" ]] && ingr_mod_time="NO_TIME"
                    [[ "$dbg_print" -gt 0 ]] && printf "[%s]" "$ingr_mod_time"
                    ruleingrs_arr[$rule_i]="${ruleingrs_arr[$rule_i]}{$ingr} {[$ingr_i], [$ingr_mod_time]}, "
                } else {
                    printf "ERROR????????\n"
                }
                fi
                ingr_i="$(($ingr_i +1))"
            }
            done
            # Check if rule has no deps
            if [[ $ingr_i -eq 0 ]] ; then {
                [[ "$dbg_print" -gt 0 ]] && printf "\n\t\t{NO_DEPS}"
                ruleingrs_arr[$rule_i]="{NO_DEPS}"
            }
            fi
            [[ "$dbg_print" -gt 0 ]] && printf "\n\t};\n"
            ruleingrs_arr[$rule_i]="{RULE: $rulename #$rule_i} <-- [${ruleingrs_arr[$rule_i]}]"
            rules_arr[$rule_i]="{RULE} [#$rule_i] -> {$rulename} <- {$mod_time} <- {DEPS} -> {$rule_ingredients} -> [#${#ingrs_arr[@]}]"
            rule_i="$(($rule_i +1))"
        } elif [[ "$current_line" =~ $ruleline_rgx ]] ; then {
          # Line matched the ruleline regex
          #
          # Remove leading tab
            if [[ "$current_line" == "${ruleline_mark_char}"* ]] ; then {
                current_line="${current_line#"$ruleline_mark_char"}"
            } else {
                printf "ERROR: matched ruleline regex but slipped the leading tab removal.\n" >&2
                printf "Current line: {%s}\n." "$current_line" >&2
                exit 1
            }
            fi
            # We found an expression inside a rule (rule scope)
            [[ "$dbg_print" -gt 0 ]] && printf "\t{RULE_EXPR} -> {%s}, [#%s]," "$current_line" "$rulexpr_i"
            #printf "In rule: {%s}\n" "$last_rulename"
            [[ "$dbg_print" -gt 0 ]] && printf "\n"
            rulexpr_arr[$rule_i]="${rulexpr_arr[$rule_i]}{RULE_EXPR #$rulexpr_i} {$current_line}, "
            rulexpr_i="$(($rulexpr_i +1))"
        } else {
          if [[ -z "$current_line" ]] ; then {
              continue
          } else {
            inside_rule=0
            rulexpr_i=0
          }
          fi
          if [[ -z "$last_rulename" ]]; then {
            # We found an expression before any rule (main scope)
            #
            # We don't have to print them now if we collect them and group print later
            #
            [[ "$dbg_print" -gt 0 ]] && printf "{EXPR_MAIN} -> "
            [[ "$dbg_print" -gt 0 ]] && printf "{%s}, [#%s],\n" "$current_line" "$mainexpr_i"
            mainexpr_arr[$mainexpr_i]="{EXPR_MAIN} -> {$current_line}, [#$mainexpr_i]"
            mainexpr_i="$(($mainexpr_i +1))"
          } else {
            # We found an expression outside a rule, after finding at least one rule (main scope)
            #
            # We don't have to print them now if we collect them and group print later
            #
            local start_w_space_regex='^ +'
            [[ "$dbg_print" -gt 0 ]] && printf "{EXPR_MAIN} -> "
            [[ "$dbg_print" -gt 0 ]] && printf "{%s}, [#%s],\n" "$current_line" "$mainexpr_i"
            if [[ "$report_warns" -gt 0 && "$current_line" =~ $start_w_space_regex ]] ; then {
                printf "\033[1;33mWARN:    a recipe line must start with a tab.\033[0m\n"
                printf "\033[1;33m%s\033[0m\n" "$current_line"
                printf "\033[1;33m^^^ Any recipe line starting with a space will be interpreted as a main expression.\033[0m\n"
                tot_warns="$((tot_warns +1))"
            }
            fi
            mainexpr_arr[$mainexpr_i]="{EXPR_MAIN} -> {$current_line}, [#$mainexpr_i]"
            mainexpr_i="$(($mainexpr_i +1))"
          }
          fi
        }
        fi
    }
    done < "$input"

    [[ "$skip_recap" -gt 0 ]] && return "$tot_warns"
    printf "{MAIN} -> {\n"
    for mexpr in "${mainexpr_arr[@]}"; do {
        printf "\t[%s],\n" "$mexpr"
    }
    done
    printf "}\n"

    printf "{RULES} -> {\n"
    for rul in "${rules_arr[@]}"; do {
        printf "\t[%s],\n" "$rul"
    }
    done
    printf "}\n"

    printf "{DEPS} -> {\n"
    for dep in "${ruleingrs_arr[@]}"; do {
        printf "\t[%s],\n" "$dep"
    }
    done
    printf "}\n"

    local rl_i=0
    printf "{RULE_EXPRS} -> {\n"
    for r_express in "${rulexpr_arr[@]}"; do {
        printf "\t[[%s] --> [%s]],\n" "${rules_arr[$rl_i]}" "$r_express"
        rl_i="$((rl_i +1))"
    }
    done
    printf "}\n"
    return "$tot_warns"
}

function najlo_main() {
#TODO: add real option handling
local prog_name="$(readlink -f "$0")"
local base_prog_name="$(basename "$prog_name")"
local res=0
case "$1" in
    "-s") {
      shift
      lex_makefile "$@" 0 0 1 1
      res="$?"
    }
    ;;
    "-v") {
      echo_najlo_version_short
      exit 0
    }
    ;;
    "-vv") {
      echo_najlo_version
      exit 0
    }
    ;;
    "-d") {
      shift
      lex_makefile "$@" 1 0 1 0
      res="$?"
    }
    ;;
    "-q") {
      shift
      lex_makefile "$@" 0 1 1 0
      res="$?"
    }
    ;;
    *) {
      echo_najlo_splash "$najlo_version" "$base_prog_name"
      lex_makefile "$@" 0 0 1 1
      res="$?"
    }
    ;;
esac
if [[ "$res" -ne 0 ]] ; then {
  printf "%s(): errors while lexing. One of the recipe lines may be starting with a space.\n" "${FUNCNAME[0]}"
}
fi
return "$res"
}
