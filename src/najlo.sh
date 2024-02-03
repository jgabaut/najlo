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
# Output format:
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

najlo_version="0.0.1"
rule_rgx='^([[:graph:]^:]+:){1,1}([[:space:]]*[[:graph:]]*)*$'

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
    local input="$1"

    [[ -f "$input" ]] || { printf "{%s} was not a valid file.\n" "$input"; exit 1 ; }

    local rulename=""
    local rule_ingredients=""
    local last_rulename=""
    local inside_rule=0
    local comment=""
    local line=""
    local ingrs_arr=""
    local ingr_i=0
    local ingr_mod_time=""
    while read -r line; do {
        #[[ ! -z "$line" ]] && printf "line: {%s}\n" "$line"
        comment="$(cut -f2 -d'#' <<< "$line")"
        line="$(cut -f1 -d'#' <<< "$line")"
        rulename="$(cut -f1 -d":" <<< "$line")"
        rule_ingredients="$(cut -f2 -d":" <<< "$line")"
        if [[ ! -z "$rulename" ]] ; then {
            # We found a valid rulename
            if [[ "$line" =~ $rule_rgx ]] ; then {
                # Line matched rule regex
                inside_rule=1
                last_rulename="$rulename"
                ingr_i=0
                mod_time="$(date -r "$rulename" +%s 2>/dev/null)"
                [[ -z "$mod_time" ]] && mod_time="NO_TIME"
                printf "{RULE} -> {%s} <- {%s}" "$rulename" "$mod_time"
                printf "\n\t<- {DEPS} -> {%s} ->" "$rule_ingredients"
                ingrs_arr=( $rule_ingredients )
                printf " [#%s] ->" "${#ingrs_arr[@]}"
                for ingr in "${ingrs_arr[@]}" ; do {
                    #printf "\n\t[[ingr: $ingr]] - [[$rule_ingredients]]\n"
                    if [[ ! -z "$ingr" ]] ; then {
                        printf "\n\t\t{INGR} - {%s} [%s], " "$ingr" "$ingr_i"
                        ingr_mod_time="$(date -r "$rulename" +%s 2>/dev/null)"
                        [[ -z "$ingr_mod_time" ]] && ingr_mod_time="NO_TIME"
                        printf "[%s]" "$ingr_mod_time"
                    } else {
                        printf "ERROR????????\n"
                    }
                    fi
                    ingr_i="$(($ingr_i +1))"
                }
                done
                # Check if rule has no deps
                [[ $ingr_i -eq 0 ]] && printf "\n\t\t{NO_DEPS}"
                printf "\n\t};\n"
                #while read -r rule_line; do {
                #    rulelines_read="$((rulelines_read +1))"
                #    if [[ "$rule_line" =~ $rule_line_rgx ]] ; then {
                #        printf "rule_line: {%s}\n" "$rule_line" >> "$output"
                #    } elif [[ "$rule_line" =~ $rule_rgx ]] ; then {
                #        # Got to a new rule
                #        printf "rulename: {%s}\n" "$rule_line" "$output"
                #        break
                #    }
                #    fi
                #}
                #done
            } else {
              # Line did not match the regex
              if [[ -z "$last_rulename" ]]; then {
                # We found an expression outside of any rule (main scope)
                printf "{EXPR} -> "
                printf "{%s}\n" "$line"
              } elif [[ "$inside_rule" -eq 1 ]]; then {
                :
                #printf "Inside RULE{%s} -> {last: %s}\n" "$rulename" "$last_rulename"
              } elif [[ -z "$line" ]]; then {
                #An empty line breaks the rule context.
                inside_rule=0
              }
              fi
              if [[ "$inside_rule" -eq 1 ]] ; then {
                # We found an expression inside a rule (rule scope)
                printf "\t{RULE_EXPR} -> {%s}" "$line"
                #printf "In rule: {%s}\n" "$last_rulename"
                printf "\n"
              }
              fi
            }
            fi
        } else {
            # We didn't find a valid rulename
            inside_rule=0
            # We reset last_rulename in order to catch any further EXPR after encountering at least one rule
            last_rulename=""
            rule_ingredients="$(cut -f2 -d":" <<< "$line")"
            if [[ ! -z "$rule_ingredients" ]] ; then {
              printf "UNEXPECTED:  should not enter here.\n" && exit 1
              printf "RULE: {%s}\n" "$rulename"
              printf "RULE_INGREDIENTS: {%s}\n" "$rule_ingredients"
            } elif [[ ! -z "$line" ]]; then {
                # We found an EXPR (non-empty line, not matching a rule)
                printf "{EXPR} -> "
                printf "{%s}\n" "$line"
            }
            fi
        }
        fi
    }
    done < "$input"
}

function najlo_main() {
#TODO: add real option handling
local prog_name="$(readlink -f "$0")"
local base_prog_name="$(basename "$prog_name")"
case "$1" in
    "-s") {
      shift
      lex_makefile "$@"
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
    *) {
        echo_najlo_splash "$najlo_version" "$base_prog_name"
        lex_makefile "$@"
        :
    }
    ;;
esac
}
