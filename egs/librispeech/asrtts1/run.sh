#!/bin/bash

# Copyright 2017 Johns Hopkins University (Shinji Watanabe)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh
. ./cmd.sh

# general configuration
backend=pytorch
stage=-1       # start from -1 if you need to start from data download
stop_stage=100
ngpu=0         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=0      # verbose option
resume=        # Resume the training from snapshot

# feature configuration
do_delta=false
# feature extraction related
fs=16000      # sampling frequency
fmax=""       # maximum frequency
fmin=""       # minimum frequency
n_mels=80     # number of mel basis
n_fft=1024    # number of fft points
n_shift=256   # number of shift points
win_length="" # window length

# network architecture
# encoder related
etype=vggblstm     # encoder architecture type
elayers=5
eunits=1024
eprojs=1024
subsample=1_2_2_1_1 # skip every n frame from input to nth layers
# decoder related
dlayers=2
dunits=1024
# attention related
atype=location
adim=1024
aconv_chans=10
aconv_filts=100

# hybrid CTC/attention
mtlalpha=0.5

# minibatch related
batchsize=20
maxlen_in=800  # if input length  > maxlen_in, batchsize is automatically reduced
maxlen_out=150 # if output length > maxlen_out, batchsize is automatically reduced

# other config
drop=0.2

# optimization related
sortagrad=0 # Feed samples from shortest to longest ; -1: enabled for all epochs, 0: disabled, other: enabled for 'other' epochs
opt=adadelta
epochs=10
patience=3

# rnnlm related
lm_layers=1
lm_units=1024
lm_opt=sgd        # or adam
lm_sortagrad=0 # Feed samples from shortest to longest ; -1: enabled for all epochs, 0: disabled, other: enabled for 'other' epochs
lm_batchsize=1024 # batch size in LM training
lm_epochs=20      # if the data size is large, we can reduce this
lm_patience=3
lm_maxlen=40      # if sentence length > lm_maxlen, lm_batchsize is automatically reduced
lm_resume=        # specify a snapshot file to resume LM training
lmtag=            # tag for managing LMs

# decoding parameter
lm_weight=0.7
beam_size=20
penalty=0.0
maxlenratio=0.0
minlenratio=0.0
ctc_weight=0.5
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'

# scheduled sampling option
samp_prob=0.0

# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
datadir=/export/a15/vpanayotov/data

# base url for downloads.
data_url=www.openslr.org/resources/12

# bpemode (unigram or bpe)
nbpe=5000
bpemode=unigram

# training related
asr_train=true
asr_decode=true
tts_train=true
tts_decode=true
asrtts_train=true
asrtts_decode=true
# exp tag
tag="" # tag for managing experiments.
asr_model_conf=$PWD/pretrained_models/librispeech_100/asr/results/model.json
asr_model=$PWD/pretrained_models/librispeech_100/asr/results/model.acc.best
rnnlm_model=$PWD/rnnlm_models/librispeech_360/rnnlm.model.best
rnnlm_model_conf=$PWD/rnnlm_models/librispeech_360/model.json
tts_model=$PWD/pretrained_models/librispeech_100/tts/results/model.loss.best
tts_model_conf=$PWD/pretrained_models/librispeech_100/tts/results/model.json
spk_vectors=exp/xvector_nnet_1a

. utils/parse_options.sh || exit 1;

. ./path.sh
. ./cmd.sh

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set=train_960
train_paired_set=train_100
train_unpaired_set=train_360
train_dev=dev
recog_set="test_clean test_other dev_clean dev_other"

if [ ${stage} -le -3 ] && [ ${stop_stage} -ge -3 ]; then
    echo "stage -3: Data Download"
    for part in dev-clean test-clean dev-other test-other train-clean-100 train-clean-360 train-other-500; do
        local/download_and_untar.sh ${datadir} ${data_url} ${part}
    done
fi
if [ ${stage} -le -2 ] && [ ${stop_stage} -ge -2 ]; then
    ### Task dependent. You have to make data the following preparation part by yourself.
    ### But you can utilize Kaldi recipes in most cases
    echo "stage -2: Data preparation"
    for part in dev-clean test-clean dev-other test-other train-clean-100 train-clean-360 train-other-500; do
        # use underscore-separated names in data directories.
        local/data_prep.sh ${datadir}/LibriSpeech/${part} data/${part//-/_}
    done
fi
dev_set=$train_dev
eval_set=test_clean
feat_tr_dir=${dumpdir}/${train_set}; mkdir -p ${feat_tr_dir}
feat_dt_dir=${dumpdir}/${dev_set}; mkdir -p ${feat_dt_dir}
feat_ev_dir=${dumpdir}/${eval_set}; mkdir -p ${feat_ev_dir}
dict=data/lang_1char/${train_set}_units.txt

if [ ${stage} -le -1 ] && [ ${stop_stage} -ge -1 ]; then
    echo "stage -1: Feature extraction for TTS and ASR"
    scripts/feat_extract.sh $train_set $train_dev $recog_set
    fbankdir=fbank
    for x in dev_clean test_clean train_clean_100 train_clean_360; do
        make_fbank.sh --cmd "${train_cmd}" --nj ${nj} \
            --fs ${fs} \
            --fmax "${fmax}" \
            --fmin "${fmin}" \
            --n_fft ${n_fft} \
            --n_shift ${n_shift} \
            --win_length "${win_length}" \
            --n_mels ${n_mels} \
            data/${x} \
            exp/make_fbank/${x} \
            ${fbankdir}
    done
    utils/combine_data.sh data/${train_set}_org data/train_clean_100 data/train_clean_360
    utils/combine_data.sh data/${dev_set}_org data/dev_clean
    # remove utt having more than 3000 frames
    # remove utt having more than 400 characters
    remove_longshortdata.sh --maxframes 3000 --maxchars 400 data/${train_set}_org data/${train_set}
    remove_longshortdata.sh --maxframes 3000 --maxchars 400 data/${dev_set}_org data/${dev_set}
    # compute global CMVN
    compute-cmvn-stats scp:data/${train_set}/feats.scp data/${train_set}/cmvn.ark
    # dump features for training
    dump.sh --cmd "$train_cmd" --nj ${nj} --do_delta false \
        data/${train_set}/feats.scp data/${train_set}/cmvn.ark exp/dump_feats/train ${feat_tr_dir}
    dump.sh --cmd "$train_cmd" --nj ${nj} --do_delta false \
        data/${dev_set}/feats.scp data/${train_set}/cmvn.ark exp/dump_feats/dev ${feat_dt_dir}
    dump.sh --cmd "$train_cmd" --nj ${nj} --do_delta false \
        data/${eval_set}/feats.scp data/${train_set}/cmvn.ark exp/dump_feats/eval ${feat_ev_dir}
    echo "dictionary: ${dict}"
    ### Task dependent. You have to check non-linguistic symbols used in the corpus.
    mkdir -p data/lang_1char/
    echo "<unk> 1" > ${dict} # <unk> must be 1, 0 will be used for "blank" in CTC
    text2token.py -s 1 -n 1 data/${train_set}/text | cut -f 2- -d" " | tr " " "\n" \
    | sort | uniq | grep -v -e '^\s*$' | awk '{print $0 " " NR+1}' >> ${dict}
    wc -l ${dict}

    # make json labels
    data2json.sh --feat ${feat_tr_dir}/feats.scp \
         data/${train_set} ${dict} > ${feat_tr_dir}/data.json
    data2json.sh --feat ${feat_dt_dir}/feats.scp \
         data/${dev_set} ${dict} > ${feat_dt_dir}/data.json
    data2json.sh --feat ${feat_ev_dir}/feats.scp \
         data/${eval_set} ${dict} > ${feat_ev_dir}/data.json
    # Make MFCCs and compute the energy-based VAD for each dataset
    mfccdir=mfcc
    vaddir=mfcc
    for name in ${train_set} ${dev_set} ${eval_set}; do
        utils/copy_data_dir.sh data/${name} data/${name}_mfcc
        steps/make_mfcc.sh \
            --write-utt2num-frames true \
            --mfcc-config conf/mfcc.conf \
            --nj ${nj} --cmd "$train_cmd" \
            data/${name}_mfcc exp/make_mfcc ${mfccdir}
        utils/fix_data_dir.sh data/${name}_mfcc
        sid/compute_vad_decision.sh --nj ${nj} --cmd "$train_cmd" \
            data/${name}_mfcc exp/make_vad ${vaddir}
        utils/fix_data_dir.sh data/${name}_mfcc
    done
    # Check pretrained model existence
    nnet_dir=exp/xvector_nnet_1a
    if [ ! -e ${nnet_dir} ];then
        echo "X-vector model does not exist. Download pre-trained model."
        wget http://kaldi-asr.org/models/8/0008_sitw_v2_1a.tar.gz
        tar xvf 0008_sitw_v2_1a.tar.gz
        mv 0008_sitw_v2_1a/exp/xvector_nnet_1a exp
        rm -rf 0008_sitw_v2_1a.tar.gz 0008_sitw_v2_1a
    fi
    # Extract x-vector
    for name in ${train_set} ${dev_set} ${eval_set}; do
        sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj ${nj} \
            ${nnet_dir} data/${name}_mfcc \
            ${nnet_dir}/xvectors_${name}
    done
    # Update json
    for name in ${train_set} ${dev_set} ${eval_set}; do
        local/update_json.sh ${dumpdir}/${name}/data.json ${nnet_dir}/xvectors_${name}/xvector.scp
    done

fi

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "stage 0: ASR training and decode"
    lmexpname=train_rnnlm_${backend}_${lmtag}_${bpemode}${nbpe}
    lmexpdir=exp/${lmexpname}
    mkdir -p ${lmexpdir}
    lmdatadir=data/local/lm_train_${bpemode}${nbpe}
    mkdir -p ${lmdatadir}
    # use external data
    if [ ! -e data/local/lm_train/librispeech-lm-norm.txt.gz ]; then
        wget http://www.openslr.org/resources/11/librispeech-lm-norm.txt.gz -P data/local/lm_train/
    fi
    cut -f 2- -d" " data/${train_set}/text | gzip -c > data/local/lm_train/${train_set}_text.gz
    # combine external text and transcriptions and shuffle them with seed 777
    zcat data/local/lm_train/librispeech-lm-norm.txt.gz data/local/lm_train/${train_set}_text.gz |\
        spm_encode --model=${bpemodel}.model --output_format=piece > ${lmdatadir}/train.txt
    cut -f 2- -d" " data/${train_dev}/text | spm_encode --model=${bpemodel}.model --output_format=piece \
        > ${lmdatadir}/valid.txt
    # use only 1 gpu
    if [ ${ngpu} -gt 1 ]; then
        echo "LM training does not support multi-gpu. signle gpu will be used."
    fi
    ${cuda_cmd} --gpu ${ngpu} ${lmexpdir}/train.log \
        lm_train.py \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --verbose 1 \
        --outdir ${lmexpdir} \
        --tensorboard-dir tensorboard/${lmexpname} \
        --train-label ${lmdatadir}/train.txt \
        --valid-label ${lmdatadir}/valid.txt \
        --resume ${lm_resume} \
        --layer ${lm_layers} \
        --unit ${lm_units} \
        --opt ${lm_opt} \
        --sortagrad ${lm_sortagrad} \
        --batchsize ${lm_batchsize} \
        --epoch ${lm_epochs} \
        --patience ${lm_patience} \
        --maxlen ${lm_maxlen} \
        --dict ${dict}
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    expdir=exp/asr_train
    expname=asr_train
    if [ $asr_train == 'true' ]; then
    ${cuda_cmd} --gpu ${ngpu} ${expdir}/train.log \
        asr_train.py \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --outdir ${expdir}/results \
        --tensorboard-dir tensorboard/${expname} \
        --debugmode ${debugmode} \
        --dict ${dict} \
        --debugdir ${expdir} \
        --minibatches ${N} \
        --verbose ${verbose} \
        --resume ${resume} \
        --train-json ${feat_tr_dir}/data_${bpemode}${nbpe}.json \
        --valid-json ${feat_dt_dir}/data_${bpemode}${nbpe}.json \
        --etype ${etype} \
        --elayers ${elayers} \
        --eunits ${eunits} \
        --eprojs ${eprojs} \
        --subsample ${subsample} \
        --dlayers ${dlayers} \
        --dunits ${dunits} \
        --atype ${atype} \
        --adim ${adim} \
        --aconv-chans ${aconv_chans} \
        --aconv-filts ${aconv_filts} \
        --mtlalpha ${mtlalpha} \
        --batch-size ${batchsize} \
        --maxlen-in ${maxlen_in} \
        --maxlen-out ${maxlen_out} \
        --sampling-probability ${samp_prob} \
        --dropout-rate ${drop} \
        --opt ${opt} \
        --sortagrad ${sortagrad} \
        --epochs ${epochs} \
        --patience ${patience}

    fi
    if [ $asr_decode == 'true' ]; then
    nj=32

    pids=() # initialize pids
    for rtask in ${recog_set}; do
    (
        decode_dir=decode_${rtask}_beam${beam_size}_e${recog_model}_p${penalty}_len${minlenratio}-${maxlenratio}_ctcw${ctc_weight}_rnnlm${lm_weight}_${lmtag}
        feat_recog_dir=${dumpdir}/${rtask}/delta${do_delta}

        # split data
        splitjson.py --parts ${nj} ${feat_recog_dir}/data_${bpemode}${nbpe}.json

        #### use CPU for decoding
        ngpu=0

        # set batchsize 0 to disable batch decoding
        ${decode_cmd} JOB=1:${nj} ${expdir}/${decode_dir}/log/decode.JOB.log \
            asr_recog.py \
            --ngpu ${ngpu} \
            --backend ${backend} \
            --batchsize 0 \
            --recog-json ${feat_recog_dir}/split${nj}utt/data_${bpemode}${nbpe}.JOB.json \
            --result-label ${expdir}/${decode_dir}/data.JOB.json \
            --model ${expdir}/results/${recog_model}  \
            --beam-size ${beam_size} \
            --penalty ${penalty} \
            --maxlenratio ${maxlenratio} \
            --minlenratio ${minlenratio} \
            --ctc-weight ${ctc_weight} \
            --rnnlm ${lmexpdir}/rnnlm.model.best \
            --lm-weight ${lm_weight}

        score_sclite.sh --bpe ${nbpe} --bpemodel ${bpemodel}.model --wer true ${expdir}/${decode_dir} ${dict}

    ) &
    pids+=($!) # store background pids
    done
    i=0; for pid in "${pids[@]}"; do wait ${pid} || ((++i)); done
    [ ${i} -gt 0 ] && echo "$0: ${i} background jobs are failed." && false
    echo "Finished"
    fi
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: TTS training, decode and synthesize"
    ttsexpdir=exp/tts_train_decode
    if [ $tts_train == 'true' ]; then
    ${cuda_cmd} --gpu ${ngpu} ${ttsexpdir}/train.log \
        tts_train.py \
           --backend ${backend} \
           --ngpu ${ngpu} \
           --outdir ${ttsexpdir}/results \
           --tensorboard-dir tensorboard/${expname} \
           --verbose ${verbose} \
           --seed ${seed} \
           --resume ${resume} \
           --train-json ${tr_json} \
           --valid-json ${dt_json} \
           --embed_dim ${embed_dim} \
           --elayers ${elayers} \
           --eunits ${eunits} \
           --econv_layers ${econv_layers} \
           --econv_chans ${econv_chans} \
           --econv_filts ${econv_filts} \
           --dlayers ${dlayers} \
           --dunits ${dunits} \
           --prenet_layers ${prenet_layers} \
           --prenet_units ${prenet_units} \
           --postnet_layers ${postnet_layers} \
           --postnet_chans ${postnet_chans} \
           --postnet_filts ${postnet_filts} \
           --atype ${atype} \
           --adim ${adim} \
           --aconv-chans ${aconv_chans} \
           --aconv-filts ${aconv_filts} \
           --cumulate_att_w ${cumulate_att_w} \
           --use_speaker_embedding ${use_speaker_embedding} \
           --use_batch_norm ${use_batch_norm} \
           --use_concate ${use_concate} \
           --use_residual ${use_residual} \
           --use_masking ${use_masking} \
           --bce_pos_weight ${bce_pos_weight} \
           --lr ${lr} \
           --eps ${eps} \
           --dropout ${dropout} \
           --zoneout ${zoneout} \
           --reduction_factor ${reduction_factor} \
           --weight-decay ${weight_decay} \
           --sortagrad ${sortagrad} \
           --batch_sort_key ${batch_sort_key} \
           --batch-size ${batchsize} \
           --maxlen-in ${maxlen_in} \
           --maxlen-out ${maxlen_out} \
           --epochs ${epochs} \
           --patience ${patience}
        fi
    if [ $tts_decode == 'true' ]; then
    outdir=${ttsexpdir}/outputs_${model}_th${threshold}_mlr${minlenratio}-${maxlenratio}
    for name in ${dev_set} ${eval_set};do
        [ ! -e  ${outdir}/${name} ] && mkdir -p ${outdir}/${name}
        cp ${dumpdir}/${name}/data.json ${outdir}/${name}
        splitjson.py --parts ${nj} ${outdir}/${name}/data.json
        # decode in parallel
        ${train_cmd} JOB=1:${nj} ${outdir}/${name}/log/decode.JOB.log \
            tts_decode.py \
                --backend ${backend} \
                --ngpu 0 \
                --verbose ${verbose} \
                --out ${outdir}/${name}/feats.JOB \
                --json ${outdir}/${name}/split${nj}utt/data.JOB.json \
                --model ${ttsexpdir}/results/${model} \
                --threshold ${threshold} \
                --maxlenratio ${maxlenratio} \
                --minlenratio ${minlenratio}
        # concatenate scp files
        for n in $(seq ${nj}); do
            cat "${outdir}/${name}/feats.$n.scp" || exit 1;
        done > ${outdir}/${name}/feats.scp
    done
    for name in ${dev_set} ${eval_set};do
        [ ! -e ${outdir}_denorm/${name} ] && mkdir -p ${outdir}_denorm/${name}
        apply-cmvn --norm-vars=true --reverse=true data/${train_set}/cmvn.ark \
            scp:${outdir}/${name}/feats.scp \
            ark,scp:${outdir}_denorm/${name}/feats.ark,${outdir}_denorm/${name}/feats.scp
        convert_fbank.sh --nj ${nj} --cmd "${train_cmd}" \
            --fs ${fs} \
            --fmax "${fmax}" \
            --fmin "${fmin}" \
            --n_fft ${n_fft} \
            --n_shift ${n_shift} \
            --win_length "${win_length}" \
            --n_mels ${n_mels} \
            ${outdir}_denorm/${name} \
            ${outdir}_denorm/${name}/log \
            ${outdir}_denorm/${name}/wav
    done
    fi
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 1: TTS training, decode and synthesize"
    scripts/asrtts_train.sh $train_set $train_set ${spk_vector}/xvectors_$train_set \
        $train_set $train_unpaired_set $train_dev $recog_set \
        $asrttsexpdir "dualp" "ce"

    feat_tr_paired_dir=dump/$train_paired_set/deltafalse
    feat_tr_unpaired_dir=dump/$train_unpaired_set/deltafalse

    if [ ! -s  ${feat_tr_unpaired_set}/data_rnd.json ]; then
        local/rand_datagen.sh --jsonout "data_rnd.json" --xvec ${spk_vector} dump/$train_speech_set/deltafalse dump/$train_text_set/deltafalse $feat_tr_unpaired_dir
    fi

    if [ $unpair == 'dual' ]; then
        tr_json_list="${feat_tr_unpaired_dir}/data_rnd.json"
    elif [ $unpair == 'dualp' ]; then
       tr_json_list="${feat_tr_unpaired_dir}/data_rnd.json ${feat_tr_paired_dir}/data.json"
    else
        tr_json_list="${feat_tr_paired_dir}/data.json"
    fi
    if [ "$policy_gradient" = "true" ]; then
        expdir=${expdir}_exploss_pgrad
        train_opts="$train_opts --policy-gradient"
    fi
    if [ "$rnnlm_loss" = "ce" ]; then
        expdir=${expdir}_rnnlmloss_${rnnlm_loss}
        train_opts="$train_opts --rnnlm $rnnlm_model --rnnlm-conf $rnnlm_model_conf --rnnloss ce" 
    elif [ "$rnnlm_loss" = "kld" ]; then
        expdir=${expdir}_rnnlmloss_${rnnlm_loss}
        train_opts="$train_opts --rnnlm $rnnlm_model --rnnlm-conf $rnnlm_model_conf --rnnloss kld" 
    elif [ "$rnnlm_loss" = "mmd" ]; then
        expdir=${expdir}_rnnlmloss_${rnnlm_loss}
        train_opts="$train_opts --rnnlm $rnnlm_model --rnnlm-conf $rnnlm_model_conf --rnnloss mmd" 
    elif [ "$rnnlm_loss" = "kl" ]; then
        expdir=${expdir}_rnnlmloss_${rnnlm_loss}
        train_opts="$train_opts --rnnlm $rnnlm_model --rnnlm-conf $rnnlm_model_conf --rnnloss kl" 
    fi
    if [ $asrtts_train == 'true' ]; then
        echo "stage 4: Network Training"
        ${cuda_cmd} --gpu ${ngpu} ${expdir}/train.log \
        asrtts_train.py \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --outdir ${expdir}/results \
        --debugmode ${debugmode} \
        --dict ${dict} \
        --debugdir ${expdir} \
        --minibatches ${N} \
        --verbose ${verbose} \
        --resume ${resume} \
        --train-json ${tr_json_list} \
        --valid-json ${feat_dt_dir}/data.json \
        --etype ${etype} \
        --elayers ${elayers} \
        --eunits ${eunits} \
        --eprojs ${eprojs} \
        --subsample ${subsample} \
        --dlayers ${dlayers} \
        --dunits ${dunits} \
        --atype ${atype} \
        --aconv-chans ${aconv_chans} \
        --aconv-filts ${aconv_filts} \
        --mtlalpha ${mtlalpha} \
        --batch-size ${batchsize} \
        --maxlen-in ${maxlen_in} \
        --maxlen-out ${maxlen_out} \
        --opt ${opt} \
        --epochs ${epochs} \
        --asr-model-conf $asr_model_conf \
        --asr-model $asr_model \
        --tts-model-conf $tts_model_conf \
        --tts-model $tts_model \
        --criterion acc \
        --update-asr-only \
        --generator tts \
        --sample-topk $sample_topk \
        --sample-scaling $sample_scaling \
        --teacher-weight $teacher_weight \
        --n-samples-per-input $n_samples \
        $train_opts
    fi
    if [ $asrtts_decode == 'true' ]; then
        echo "stage 5: Decoding"
        nj=32
        for rtask in ${recog_set}; do
        (
            recog_opts=
            if [ $use_rnnlm = true ]; then
                decode_dir=decode_${rtask}_beam${beam_size}_e${recog_model}_p${penalty}_len${minlenratio}-${maxlenratio}_ctcw${ctc_weight}_rnnlm${lm_weight}
                recog_opts="$recog_opts --lm-weight ${lm_weight} --rnnlm ${lmexpdir}/rnnlm.model.best"
            else
                decode_dir=decode_${rtask}_beam${beam_size}_e${recog_model}_p${penalty}_len${minlenratio}-${maxlenratio}_ctcw${ctc_weight}
            fi
            feat_recog_dir=${dumpdir}/${rtask}/delta${do_delta}

            # split data
            splitjson.py --parts ${nj} ${feat_recog_dir}/data.json 

            #### use CPU for decoding
            ngpu=0

            ${decode_cmd} JOB=1:${nj} ${expdir}/${decode_dir}/log/decode.JOB.log \
            asr_recog.py \
            --ngpu ${ngpu} \
            --backend ${backend} \
            --recog-json ${feat_recog_dir}/split${nj}utt/data.JOB.json \
            --result-label ${expdir}/${decode_dir}/data.JOB.json \
            --model ${expdir}/results/model.${recog_model}  \
            --model-conf ${expdir}/results/model.json  \
            --beam-size ${beam_size} \
            --penalty ${penalty} \
            --maxlenratio ${maxlenratio} \
            --minlenratio ${minlenratio} \
            --ctc-weight ${ctc_weight} \
            $recog_opts \
            &
            wait
            score_sclite.sh --wer true ${expdir}/${decode_dir} ${dict}

        ) &
        done
        wait
        echo "Finished"
    fi
fi

