def write_scp(scp_name, fbk_name, feat_path):
    with open(fbk_name, 'r') as fbk:
        fbk_lines = fbk.readlines()
        for lin_num, x in enumerate(fbk_lines):
            feat_name = x.split("/fbk/")[1]
            rhs = ''.join([feat_path, feat_name])

            #generating lhs
            feat_lhs = feat_name.replace('_', '-').replace('.fbk', '')
            if 'A' in feat_lhs:
                uttrID1 = feat_lhs.split('-A-')[0]
                uttrID2 = feat_lhs.split('-A-')[1][:-6]
                timetag = '0' + feat_lhs.split('-A-')[1][-6:]
                lhs = ''.join(['BPL', uttrID1, '-', uttrID2, 'in', '_CIXXXXX_', timetag, '_XXXXXXX'])

            elif 'B' in feat_lhs:
                uttrID1 = feat_lhs.split('-B-')[0]
                uttrID2 = feat_lhs.split('-B-')[1][:-6]
                timetag = '0' + feat_lhs.split('-B-')[1][-6:]
                lhs = ''.join(['BPL', uttrID1, '-', uttrID2, 'out', '_CIXXXXX_', timetag, '_XXXXXXX'])

            else:
                print("WRONGGGGGGGGGGGG")

            fbk_lines[lin_num] = ''.join([lhs, '=', rhs, '\n'])

    with open(scp_name, 'w') as scp:
        for line in fbk_lines:
            scp.writelines(line)


def main():
    scp_name = '/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_/outputs_snapshot.ep.200_denorm/convert/dev.scp'
    fbk_name = '/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_/outputs_snapshot.ep.200_denorm/convert/lib/coding/segmented.dev.fbk'
    feat_path = '/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/exp/tts_/outputs_snapshot.ep.200_denorm/fbk/'
    write_scp(scp_name, fbk_name, feat_path)


if __name__ == "__main__":
    main()