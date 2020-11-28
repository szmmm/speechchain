def clean_up_json(text_file, json_file):
    with open(text_file, 'r') as text:
        text_lines = text.readlines()
        noisy_data_id = []
        for line in text_lines:
            if "<v-noise>" in line or "<noise>" in line or "<unk>" in line or "<hes>" in line:
                noisy_data_id.append(line.split()[0])
    print(len(noisy_data_id))
    index = []
    with open(json_file, 'r') as json:
        json_lines = json.readlines()
        for line in json:
            for ids in noisy_data_id:
                if ids in line:
                    index.append(json_lines.index(line))
    # with open(new_json, 'w') as new:
    #     index = []
    #     for ids in noisy_data_id:
    #         for line in json_lines:
    #             if ids in line:
    #                 index.append(json_lines.index(line))
    return index
        #new.writelines(json_lines)


if __name__ == '__main__':
    # text_f = "C:/Users/matt/Desktop/4th Year Project/text"
    # json_f = "C:/Users/matt/Desktop/4th Year Project/data_tts.json"
    # newjson_f = "C:/Users/matt/Desktop/4th Year Project/new.json"
    text_f = "/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/data/train/text"
    json_f = "/data/mifs_scratch/mjfg/zs323/yr4project/speechchain/egs/babel/asrtts/dump_unclean/train/data_tts.json"
    index_list = clean_up_json(text_f, json_f)
    print(len(index_list))
