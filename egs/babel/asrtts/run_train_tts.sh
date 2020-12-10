#!/bin/bash
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

./run.sh \
    --stage 4 \
    --stop_stage 4 \
    --resume /data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_clean/results/snapshot.ep.234