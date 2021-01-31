import numpy as np

def generate_text(ctm, uttr_ctm, uttr_map):
    with open(uttr_ctm) as utt:
        utt_line = utt.readlines()
        utt_dict = {}
        duration_dict = {}
        for line in utt_line:
            utt_name = line.split()[0]
            word = line.split()[4]
            duration = float(line.split()[3])
            if utt_name not in utt_dict.keys():
                utt_dict[utt_name] = [word]
                duration_dict[utt_name] = [duration]
            else:
                utt_dict[utt_name].append(word)
                duration_dict[utt_name].append(duration)
        print(len(utt_dict.keys()))

    with open(uttr_map) as mapping:
        map_lines = mapping.readlines()
        map_dict = {}
        for line in map_lines:
            map_dict[line.split()[0]] = line.split()[1]
        print(len(map_dict.keys()))

    with open(ctm) as ctm:
        ctm_lines = ctm.readlines()
        audio_dict = {}
        audio_duration_check_dict = {}
        audio_score_dict = {}
        for line in ctm_lines:
            audio_name = line.split()[0]
            word = line.split()[4]
            duration = float(line.split()[3])
            config_score = float(line.split()[5])
            average_score = config_score * duration
            if audio_name not in audio_dict.keys():
                audio_dict[audio_name] = [word]
                audio_duration_check_dict[audio_name] = [duration]
                audio_score_dict[audio_name] = [average_score]
            else:
                audio_dict[audio_name].append(word)
                audio_duration_check_dict[audio_name].append(duration)
                audio_score_dict[audio_name].append(average_score)
        print(len(audio_score_dict.keys()))
    score_dict = {}

    for utter in utt_dict.keys():
        audio = map_dict[utter]
        durations = duration_dict[utter]
        sentence = utt_dict[utter]
        assert len(durations) == len(sentence)
        total_score = 0.0
        for i in range(len(sentence)):
            total_score += audio_score_dict[audio][i]
        audio_score_dict[audio] = audio_score_dict[audio][len(sentence):]
        overall = total_score / np.sum(durations)
        if overall >= 1:
            print("Wrong!")
        score_dict[utter] = overall

    with open("C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/score", 'w') as out:
        for key in utt_dict.keys():
            out.write(key)
            out.write(' ' + str(score_dict[key]))
            out.write('\n')

    with open("C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/text", 'w') as out:
        for key in utt_dict.keys():
            if score_dict[key] > 0.7:
                out.write(key)
                for word in utt_dict[key]:
                    out.write(' ' + word)
                out.write('\n')

    low_confidence = 0
    for value in score_dict.values():
        if value < 0.7:
            low_confidence += 1
    print("There are {} utterances below threshold score".format(low_confidence))


def generate_wav_scp(input, output):
    with open(input) as wav:
        lines = wav.readlines()
        for line_num, line in enumerate(lines):
            audio_name = line.split('/src/')[1].split('.')[0]
            lines[line_num] = ''.join([audio_name, ' ', line])
        with open(output, 'w') as f:
            for line in lines:
                f.writelines(line)


if __name__ == '__main__':
    ctm = "C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/fbk_pitch_pov_kaldi.map.ctm"
    utt_ctm = "C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/fbk_pitch_pov_kaldi.utt.ctm"
    utt_map = "C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/utter_map"
    generate_text(ctm, utt_ctm, utt_map)

    input_wav = "C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/wav"
    output_wav = "C:/Users/matt/Desktop/4th Year Project/ctm files/Dev Set/wav.scp"
    generate_wav_scp(input_wav, output_wav)


