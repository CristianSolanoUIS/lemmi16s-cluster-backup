#!/usr/bin/env bash
set -e
toolname=$1
shift
script_dir="/shared/users/grupo1/lemmi16s/resources/candidate_containers/${toolname}/scripts"

export LD_LIBRARY_PATH="/shared/users/grupo1/qiime2_arm64/lib:/shared/users/grupo1/lemmi16s_env/lib:$LD_LIBRARY_PATH"

if [[ "${toolname}" == *"qiime2"* ]]; then
    export PATH="${script_dir}:/shared/users/grupo1/qiime2_arm64/bin:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/qiime2_arm64/lib/python3.8/site-packages"
    export PYTHONNOUSERSITE=1
else
    export PATH="${script_dir}:/shared/users/grupo1/lemmi16s_env/bin:$PATH"
    export PYTHONPATH="/shared/users/grupo1/lemmi16s_env/lib/python3.10/site-packages:$PYTHONPATH"
fi

if [ ! -f "${script_dir}/LEMMI16s_analysis.sh" ]; then
    echo "[ERROR] LEMMI16s_analysis.sh not found for tool ${toolname} at ${script_dir}" >&2
    exit 1
fi

exec bash "${script_dir}/LEMMI16s_analysis.sh" "$@"
