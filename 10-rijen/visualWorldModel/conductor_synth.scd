// =============================================================================
// conductor_synth.scd - Highly Responsive Gesture Conductor Synthesizer
// Immediate, dramatic, audible sonic changes:
// - Elevation (Y): Sweeps Pitch (45 Hz -> 880 Hz) and Filter Cutoff (100 Hz -> 10,000 Hz)
// - Lateral (X): Sweeps Stereo Pan (-1.0 -> +1.0)
// - Energy (Speed): Controls Volume, Distortion, and Harmonic Richness
// - Ictus Strike: Crisp resonant plucks & gong accents on every gesture beat
// =============================================================================

s.waitForBoot({
    "=========================================================".postln;
    "  GESTURE CONDUCTOR SYNTHESIZER ONLINE (KOF)".postln;
    "  Listening for OSC on UDP port 57120...".postln;
    "=========================================================".postln;

    // -------------------------------------------------------------------------
    // 1. SynthDef: The Ictus Strike (Tuned Resonant Metallic Pluck / Gong)
    // -------------------------------------------------------------------------
    SynthDef(\ictusStrike, { |freq = 220, decay = 0.5, amp = 0.7, pan = 0.0, brightness = 1.0|
        var trigger, excitation, freqs, ringTimes, modal, sig;
        
        // Fast analog transient impulse
        excitation = Decay2.ar(Impulse.ar(0), 0.0005, 0.008) * WhiteNoise.ar(0.6)
                   + (Dust2.ar(80) * 0.1);
        
        // Resonant modal frequencies (harmonic chime)
        freqs = [freq, freq * 1.5, freq * 2.01, freq * 2.76, freq * 3.45, freq * 4.2];
        ringTimes = [decay, decay * 0.7, decay * 0.5, decay * 0.35, decay * 0.2, decay * 0.1];
        
        modal = Ringz.ar(excitation, freqs, ringTimes).sum;
        modal = LPF.ar(modal, (freq * 6 * brightness).clip(200, 18000));
        
        sig = modal * amp;
        sig = sig + (CombN.ar(sig, 0.2, 0.07, 0.4) * 0.3); // Space
        
        DetectSilence.ar(sig, amp: 0.0001, time: 0.05, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 2. SynthDef: Conductor Flow (Dramatic Continuous Morphing Drone)
    // -------------------------------------------------------------------------
    SynthDef(\conductorFlow, { |out = 0, pitch = 110, cutoff = 1200, pan = 0.0, res = 1.5, energy = 0.2, span = 0.5|
        var osc1, osc2, sub, mixed, filtered, sig, lPitch, lCutoff, lPan, lRes, lEnergy;
        
        // Very fast responsive smoothing (30-40 ms)
        lPitch = Lag.kr(pitch, 0.04);
        lCutoff = Lag.kr(cutoff, 0.04);
        lPan = Lag.kr(pan, 0.04);
        lRes = Lag.kr(res, 0.05);
        lEnergy = Lag.kr(energy, 0.05);
        
        // Sub-bass foundation
        sub = SinOsc.ar(lPitch * 0.5) * 0.6;
        
        // Morphing oscillators: pitch follows hand height!
        osc1 = VarSaw.ar(lPitch, 0, (0.1 + lEnergy * 0.5).clip(0.05, 0.95)) * 0.4;
        osc2 = Pulse.ar(lPitch * 1.005, (0.2 + lEnergy * 0.4).clip(0.1, 0.9)) * 0.35;
        
        mixed = osc1 + osc2 + sub;
        
        // Resonant Moog filter: cutoff follows hand height!
        filtered = MoogFF.ar(mixed, lCutoff.clip(60, 16000), lRes.clip(0.2, 3.8));
        
        // Distortion & saturation when gesture moves fast
        filtered = (filtered * (1.0 + lEnergy * 2.5)).tanh;
        
        // Volume: scales with gesture activity
        sig = filtered * (0.15 + (lEnergy * 0.65)).clip(0.05, 1.0);
        
        Out.ar(out, Pan2.ar(sig, lPan));
    }).add;

    s.sync;

    // Start continuous drone
    ~drone = Synth(\conductorFlow, [
        \pitch, 130.8, // C3
        \cutoff, 1000,
        \pan, 0.0,
        \res, 1.2,
        \energy, 0.3,
        \span, 0.5
    ]);

    // -------------------------------------------------------------------------
    // 3. OSC Listeners
    // -------------------------------------------------------------------------

    // A. Continuous Morphing: [pitchNorm, panNorm, cutoffNorm, energyNorm]
    OSCdef(\onMorph, { |msg|
        var yElev = msg[1];    // 0.0 (low) to 1.0 (high)
        var xPan = msg[2];     // -1.0 (left) to +1.0 (right)
        var energy = msg[3];   // 0.0 to 3.0+ (speed)
        var span = msg[4];     // 0.0 to 1.5 (two hands distance)
        
        // Dramatic pitch sweep across 4 octaves (55 Hz A1 -> 880 Hz A5)
        var pitchHz = (55.0 * (2.0 ** (yElev * 4.0))).clip(45, 1200);
        
        // Dramatic filter sweep across 6 octaves (100 Hz -> 12,000 Hz)
        var cutoffHz = (100.0 * (2.0 ** (yElev * 6.5))).clip(80, 16000);
        
        var panVal = xPan.clip(-1.0, 1.0);
        var resVal = (0.5 + (span * 2.0)).clip(0.2, 3.6);
        var energyVal = energy.clip(0.0, 3.0);

        ~drone.set(
            \pitch, pitchHz,
            \cutoff, cutoffHz,
            \pan, panVal,
            \res, resVal,
            \energy, energyVal
        );
    }, '/conductor/morph');

    // B. The Ictus Strike (Accent on hand flick / snap)
    OSCdef(\onIctus, { |msg|
        var intensity = msg[1];
        var xPos = msg[2];
        var yPos = msg[3];
        
        var freq = (110.0 * (2.0 ** (yPos * 2.5))).clip(65, 880);
        var decay = (0.3 + intensity * 0.5).clip(0.15, 2.0);
        var amp = (0.4 + intensity * 0.4).clip(0.2, 1.0);
        var pan = (xPos * 2.0 - 1.0).clip(-1.0, 1.0);
        
        Synth(\ictusStrike, [
            \freq, freq,
            \decay, decay,
            \amp, amp,
            \pan, pan,
            \brightness, (0.8 + intensity).clip(0.4, 2.5)
        ]);
        
        (">>> ICTUS STRIKE: Freq=" ++ freq.round(1) ++ " Hz | Pan=" ++ pan.round(0.01) ++ " | Int=" ++ intensity.round(0.01)).postln;
    }, '/conductor/ictus');

    "Gesture Conductor Ready: Move hand vertically for PITCH/FILTER, horizontally for PAN, snap for STRIKE.".postln;
});
