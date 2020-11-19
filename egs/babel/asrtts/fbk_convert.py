
def write_fbk(file_name, feat_path):
    with open(file_name, 'r') as f:
        lines = f.readlines()
        for lin_num, x in enumerate(lines):
            audio_name = x.split("/wav/")[1].split(".")[0]
            feat_name = ''.join([feat_path, audio_name, '.fbk'])
            lines[lin_num] = ''.join([x.strip(), ' ', feat_name, '\n'])
    with open(file_name, 'w') as f:
        for line in lines:
            f.writelines(line)


def main():
    file_name = '/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_/outputs_snapshot.ep.200_denorm/convert/lib/coding/segmented_test.dev.fbk'
    feat_path = '/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_/outputs_snapshot.ep.200_denorm/fbk/'
    write_fbk(file_name, feat_path)


if __name__ == "__main__":
    main()