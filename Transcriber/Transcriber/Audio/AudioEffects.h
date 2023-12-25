//
//  AudioEffects.h
//  AudioEffects
//
//  Created by Daniel Kuntz on 8/16/21.
//

#ifndef AudioEffects_h
#define AudioEffects_h

#include <stdio.h>
#include "soundpipe.h"

typedef struct {
    int sample_rate;

    float highPassCutoffFreq;
    float pitchShift;

    sp_data *sp;
    sp_moogladder *moogladder;

    sp_buthp *buthp;
    sp_buthp *buthp2;
    sp_port *hp_port;
} AudioEffects;

AudioEffects createAudioEffects(double sample_rate);
void process_mono(AudioEffects *fx, float *input, float *output);
void set_lowpass_freq(AudioEffects *fx, float freq);
void set_highpass_freq(AudioEffects *fx, float freq);
void set_pitch_shift(AudioEffects *fx, float shift);

#endif /* AudioEffects_h */
