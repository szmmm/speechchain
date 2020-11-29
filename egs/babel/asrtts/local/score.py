import re
import numpy as np


def levenshtein(str1, str2):
    ''' From Wikipedia article; Iterative with two matrix rows. '''
    if str1 == str2:
        return 0
    elif len(str1) == 0:
        return len(str2)
    elif len(str2) == 0:
        return len(str1)
    prev_count = [0] * (len(str2) + 1)
    current_count = [0] * (len(str2) + 1)
    for i in range(len(prev_count)):
        prev_count[i] = i

    for i in range(len(str1)):
        current_count[0] = i + 1
        for j in range(len(str2)):
            cost = 0 if str1[i] == str2[j] else 1
            current_count[j + 1] = min(current_count[j] + 1, prev_count[j + 1] + 1, prev_count[j] + cost)
        for j in range(len(prev_count)):
            prev_count[j] = current_count[j]

    return current_count[len(str2)]


def generate_input(input_text, output_text):
    with open(input_text, 'r') as text:
        lines = text.readlines()
        reg = re.compile('<.*?>')
        new_lines = []
        for line in lines:
            new_line = ' '.join(re.sub(reg, '', line).split())
            new_line = new_line + '\n'
            new_lines.append(new_line)
    with open(output_text, 'w') as out:
        out.writelines(new_lines)


#def generate_output(input_ctm, output_ctm):


if __name__ == '__main__':
    print(levenshtein('pythern asdasd', 'pethon asd sad'))
    text_in = "C:/Users/matt/Desktop/4th Year Project/DATA/text_eval"
    text_out = "C:/Users/matt/Desktop/4th Year Project/DATA/text_eval_no_tag"
    generate_input(text_in, text_out)