#!/bin/bash

# Copyright 2018 Johns Hopkins University (Matthew Wiesner)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh
. ./cmd.sh
. ./conf/lang.conf

langs="106"
test="106"
FLP=true

. ./utils/parse_options.sh

set -e
set -o pipefail

all_langs=""
for l in `cat <(echo ${langs}) <(echo ${test}) | tr " " "\n" | sort -u`; do
  all_langs="${l} ${all_langs}"
done
all_langs=${all_langs%% }

# Save top-level directory
cwd=$(utils/make_absolute.sh `pwd`)
echo "Stage 0: Setup Language Specific Directories"

echo " --------------------------------------------"
echo "Languagues: ${all_langs}"

# Basic directory prep
for l in ${all_langs}; do
  [ -d data/${l} ] || mkdir -p data/${l}
  cd data/${l}

  ln -sf ${cwd}/local .
  for f in ${cwd}/{utils,steps,conf}; do
    link=`make_absolute.sh $f`
    ln -sf $link .
  done

  cp ${cwd}/cmd.sh .
  cp ${cwd}/path.sh .
  sed -i 's/\.\.\/\.\.\/\.\./\.\.\/\.\.\/\.\.\/\.\.\/\.\./g' path.sh
  
  cd ${cwd}
done

# Prepare language specific data
for l in ${all_langs}; do
  (
    cd data/${l}
    ./local/prepare_data.sh --FLP ${FLP} ${l}
    cd ${cwd}
  ) &
done
wait

# Combine all language specific training directories and generate a single
# lang directory by combining all language specific dictionaries
train_dirs=""
dev_dirs=""
eval_dirs=""
for l in ${langs}; do
  train_dirs="data/${l}/data/train_${l} ${train_dirs}"
done

for l in ${test}; do
  dev_dirs="data/${l}/data/dev_${l} ${dev_dirs}"
done

./utils/combine_data.sh data/train ${train_dirs}
./utils/combine_data.sh data/dev ${dev_dirs}

for l in ${test}; do
  ln -s ${cwd}/data/${l}/data/eval_${l} ${cwd}/data/eval_${l}
done

