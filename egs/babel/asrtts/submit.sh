qsub -cwd -j yes -S /bin/bash -l qp=cuda-low -l gpuclass='*' -l osrel='*' -l hostname=air208 ./run_train_tts.sh
