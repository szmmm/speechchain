qsub -cwd -j yes -S /bin/bash -l qp=cuda-low -l gpuclass='*' -l osrel='*' -l hostname=air209 ./run_data_prep.sh
