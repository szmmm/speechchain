#!/usr/bin/env python2

# Apache 2.0
from __future__ import print_function
from __future__ import unicode_literals

import argparse
import codecs

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--exclude', '-v', dest='exclude', action='store_true', help='exclude filter words')
    parser.add_argument('filt', type=str, help='filter list')
    parser.add_argument('infile', type=str, help='input file')
    args = parser.parse_args()

    vocab = set()
    with codecs.open(args.filt, "r", encoding="utf-8") as vocabfile:
        for line in vocabfile:
            vocab.add(line.strip())

    with codecs.open(args.infile, "r", encoding="utf-8") as textfile:
        for line in textfile:
            if args.exclude:
                print(" ".join(map(lambda word: word if word not in vocab else '', line.strip().split())))
            else:
                print(" ".join(map(lambda word: word if word in vocab else '<UNK>', line.strip().split())))
