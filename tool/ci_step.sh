#!/usr/bin/env bash
# Roda um comando e, se falhar, publica o final da saída como anotação de erro
# (visível na aba "Summary" do GitHub Actions e pela API).
# Uso: bash tool/ci_step.sh "Título" comando args...
title="$1"; shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  # Linhas mais úteis primeiro: erros do analyzer/compilador
  { grep -E -A7 "thrown during layout|thrown building|thrown while|The test description was|overflowed by" "$out" | grep -v "^#[0-9]" | head -90
    grep -E "error •|Error:|error:|FAILURE|What went wrong" "$out" | head -30
    echo "-----"; grep -E "screens_test\.dart:[0-9]+|lib/.*\.dart:[0-9]+" "$out" | grep -v "package:flutter" | head -40
    echo "-----"; tail -25 "$out"; } > "$out.sum"
  msg="$(sed -e 's/%/%25/g' "$out.sum" | awk '{printf "%s%%0A", $0}')"
  echo "::error title=${title}::${msg}"
fi
exit "$code"
