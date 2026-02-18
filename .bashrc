#!/bin/bash
# is this an interactive shell?
[[ $- != *i* ]] && return

. $HOME/.local/bin/utility.sh

# This is non-login shell script
export PS1='[\u@\h \W]\$ '
export EXPERIMENT=$(hostname | sed 's/gpvm*.*//')
export appdir="/exp/$EXPERIMENT/app/users/$USER"
export datadir="/exp/$EXPERIMENT/data/users/$USER"

alias condor_q="condor_q -G $EXPERIMENT"
alias condor_rm="condor_rm -G $EXPERIMENT"
alias jobsub_q="jobsub_q -G $EXPERIMENT"
alias jobsub_rm="jobsub_rm -G $EXPERIMENT"
alias jobsub_fetchlog="jobsub_fetchlog -G $EXPERIMENT"

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# initialize pyenv
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"   # virtualenv plugin

#=_=_=_=_=_= added by fnal_utility (do not remove) =_=_=_=_=_=_=
export FNAL_UTIL_ROOT="/nashome/w/wyjang/.local/bin/../"
alias appt=". /nashome/w/wyjang/.local/bin/setup-appt.sh"
alias appt_build=". /nashome/w/wyjang/.local/bin/setup-appt-build.sh"
alias setup-spack=". /nashome/w/wyjang/.local/bin/setup-spack.sh"
alias setup-g4=". /nashome/w/wyjang/.local/bin/setup-g4.sh"
alias setup-icarus=". /nashome/w/wyjang/.local/bin/setup-icarus.sh"
alias setup-dune=". /nashome/w/wyjang/.local/bin/setup-dune.sh"
alias setup-genie-bdm=". /nashome/w/wyjang/.local/bin/setup-genie-bdm.sh"
alias setup-vnc=". /nashome/w/wyjang/.local/bin/setup-vnc.sh"
alias clearcert="rm -fv /tmp/x509up_u\$(id -u)"
alias gettoken="htgettoken -a htvaultprod.fnal.gov -i \$EXPERIMENT;export BEARER_TOKEN_FILE=/run/user/\$(id -u)/bt_u\$(id -u)"
#=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=

# 기존 cd 명령어를 확장하는 함수
cd() {
    # 1. 실제 cd 명령 실행 (command 키워드로 함수 재귀 호출 방지)
    if command cd "$@"; then
        # 2. 이동에 성공하면 프롬프트 갱신 함수 호출
        set_prompt
    fi
}

# 초기 쉘 진입 시에도 프롬프트가 설정되도록 한 번 실행
set_prompt
