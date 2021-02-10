qsub -cwd -j yes -S /bin/bash -l qp=cuda-low -l gpuclass='pascal|volta' -l osrel='*' ./run_train_tts.sh

# qsub -cwd -j yes -S /bin/bash -l qp=low -l hostname=air209 ./run_prep.sh