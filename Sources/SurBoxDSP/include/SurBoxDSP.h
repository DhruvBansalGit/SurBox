#ifndef SURBOX_DSP_H
#define SURBOX_DSP_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct SBEngine SBEngine;
SBEngine *sb_create(double sampleRate);
void sb_destroy(SBEngine *engine);
// Call load only while AVAudioEngine is stopped. Copies immutable PCM.
int sb_load_sample(SBEngine *engine, int midi, const float *samples, int count, double sampleRate, int loopStart, int loopEnd);
void sb_note(SBEngine *engine, int midi, float velocity);
void sb_controls(SBEngine *engine, float pressure, float volume, int mute);
void sb_panic(SBEngine *engine);
void sb_render(SBEngine *engine, float *output, int count);
int sb_sample_count(SBEngine *engine);
#ifdef __cplusplus
}
#endif
#endif
