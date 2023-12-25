//
//  AudioEffects.c
//  AudioEffects
//
//  Created by Daniel Kuntz on 8/16/21.
//

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "AudioEffects.h"

AudioEffects createAudioEffects(double sample_rate) {
    AudioEffects *fx;
    fx = malloc(sizeof(AudioEffects));
    fx->sample_rate = sample_rate;
    sp_create(&fx->sp);
    fx->sp->sr = sample_rate;

    sp_moogladder_create(&fx->moogladder);
    sp_moogladder_init(fx->sp, fx->moogladder);
    fx->moogladder->freq = 20000.;
    fx->moogladder->res = 0.3;

    sp_buthp_create(&fx->buthp);
    sp_buthp_init(fx->sp, fx->buthp);
    fx->buthp->freq = 10.;
    fx->highPassCutoffFreq = 10.;

    sp_buthp_create(&fx->buthp2);
    sp_buthp_init(fx->sp, fx->buthp2);
    fx->buthp2->freq = 10.;

    sp_port_create(&fx->hp_port);
    sp_port_init(fx->sp, fx->hp_port, 0.02);
    sp_port_reset(fx->sp, fx->hp_port, &fx->buthp->freq);

    return *fx;
}

void process_mono(AudioEffects *fx, float *input, float *output) {
    sp_port_compute(fx->sp, fx->hp_port, &fx->highPassCutoffFreq, &fx->buthp->freq);
    fx->buthp2->freq = fx->buthp->freq;

    float moogladder_out = 0.0;
    float buthp_out = 0.0;
    float buthp2_out = 0.0;

    sp_moogladder_compute(fx->sp, fx->moogladder, input, &moogladder_out);
    sp_buthp_compute(fx->sp, fx->buthp, &moogladder_out, &buthp_out);
    sp_buthp_compute(fx->sp, fx->buthp2, &buthp_out, &buthp2_out);

    *output = buthp2_out;
}

void set_lowpass_freq(AudioEffects *fx, float freq) {
    fx->moogladder->freq = freq;
}

void set_highpass_freq(AudioEffects *fx, float freq) {
    fx->highPassCutoffFreq = freq;
}

void set_pitch_shift(AudioEffects *fx, float shift) {
    fx->pitchShift = shift;
}
