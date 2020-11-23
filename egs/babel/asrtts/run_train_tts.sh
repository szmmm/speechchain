#!/bin/bash
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

./run.sh \
    --stage 4 \
    --stop_stage 4 \
    --resume $PWD/exp/tts_/results/snapshot.ep.400