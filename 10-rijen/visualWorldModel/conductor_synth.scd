// =============================================================================
// conductor_synth.scd - Dual-Hand SuperCollider Orchestral Synthesizer
// Seamlessly responds to ONE hand or BOTH hands:
// - Right Hand: Baton / Timekeeper (rhythmic strikes, pitch base, stereo pan)
// - Left Hand: Expressive Dynamics (modal gong accents, filter resonance, reverb)
// - Dual Hand Span: Distance between hands expands stereo field & harmonic density
// - Dual Strike (Tutti): Simultaneous downbeat triggers massive orchestral sub-drop
// =============================================================================

s.waitForBoot({
    "=========================================================".postln;
    "  DUAL-HAND GESTURE CONDUCTOR SYNTHESIZER READY (KOF)".postln;
    "  Listening for OSC on UDP port 57120...".postln;
    "=========================================================".postln;

    // -------------------------------------------------------------------------
    // 1. SynthDef: Right Hand Strike (Tuned Metallic Chime / Pluck)
    // -------------------------------------------------------------------------
    SynthDef(\rightHandStrike, { |freq = 220, decay = 0.6, amp = 0.5, pan = 0.3|
        var excitation, modal, sig;
        excitation = Decay2.ar(Impulse.ar(0), 0.0008, 0.01) * WhiteNoise.ar(0.3);
        modal = Ringz.ar(excitation, [freq, freq * 1.5, freq * 2.2, freq * 3.14], [decay, decay * 0.7, decay * 0.4, decay * 0.2]).sum;
        sig = modal * amp;
        sig = sig + (CombN.ar(sig, 0.2, 0.06, 0.5) * 0.25);
        DetectSilence.ar(sig, amp: 0.0001, time: 0.1, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 2. SynthDef: Left Hand Strike (Deep Resonant Gong / Expressive Accent)
    // -------------------------------------------------------------------------
    SynthDef(\leftHandStrike, { |freq = 90, decay = 1.4, amp = 0.6, pan = -0.3|
        var excitation, gong, sub, sig;
        excitation = Decay2.ar(Impulse.ar(0), 0.003, 0.04) * PinkNoise.ar(0.5);
        gong = Ringz.ar(excitation, [freq, freq * 1.28, freq * 1.72, freq * 2.45], [decay, decay * 0.8, decay * 0.6, decay * 0.4]).sum;
        sub = SinOsc.ar(freq * 0.5) * EnvGen.ar(Env.perc(0.01, decay * 0.9), doneAction: 0) * 0.7;
        sig = (gong * 0.6 + sub) * amp;
        DetectSilence.ar(sig, amp: 0.0001, time: 0.1, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 3. SynthDef: Dual Strike (Tutti Downbeat Explosion)
    // -------------------------------------------------------------------------
    SynthDef(\tuttiStrike, { |amp = 0.8|
        var subDrop, modal, sig;
        // Sub-bass drop 110Hz -> 40Hz
        subDrop = SinOsc.ar(XLine.ar(120, 38, 0.8)) * EnvGen.ar(Env.perc(0.01, 1.6)) * 0.8;
        // Full spectrum resonant burst
        modal = Ringz.ar(Decay2.ar(Impulse.ar(0), 0.002, 0.02) * WhiteNoise.ar(0.4), [55, 110, 165, 220, 330, 440, 660], 1.2).sum * 0.4;
        sig = (subDrop + modal) * amp;
        DetectSilence.ar(sig, amp: 0.0001, time: 0.1, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, 0.0));
    }).add;

    // -------------------------------------------------------------------------
    // 4. SynthDef: Continuous Conductor Flow (Dual-Hand Drone)
    // -------------------------------------------------------------------------
    SynthDef(\conductorDrone, { |out = 0, baseFreq = 55, cutoff = 800, res = 1.2, pan = 0.0, span = 0.5, leftElev = 0.5, energy = 0.2|
        var osc1, osc2, sub, mixed, filtered, spreadSig, sig;
        
        var lCutoff = Lag.kr(cutoff, 0.06);
        var lRes = Lag.kr(res, 0.08);
        var lPan = Lag.kr(pan, 0.06);
        var lSpan = Lag.kr(span, 0.08);
        var lLeft = Lag.kr(leftElev, 0.08);
        var lEnergy = Lag.kr(energy, 0.1);
        
        // Deep foundation
        sub = SinOsc.ar(baseFreq * 0.5) * 0.5;
        
        // Morphing dual oscillators
        osc1 = VarSaw.ar(baseFreq, 0, (0.2 + lSpan * 0.6).clip(0.05, 0.95));
        osc2 = Pulse.ar(baseFreq * 1.006, (0.3 + lLeft * 0.4).clip(0.1, 0.9));
        
        mixed = (osc1 * 0.45) + (osc2 * 0.35) + sub;
        
        // Moog filter modulated by right hand elevation & left hand resonance
        filtered = MoogFF.ar(mixed, lCutoff.clip(80, 16000), (lRes + lLeft * 1.5).clip(0.1, 3.5));
        
        // Stereo expansion based on distance between hands
        spreadSig = [
            filtered * (1.0 - lPan * 0.5).clip(0.1, 1.0),
            filtered * (1.0 + lPan * 0.5).clip(0.1, 1.0)
        ];
        
        // Left hand adds ambient shimmer / delay
        spreadSig = spreadSig + (CombN.ar(spreadSig, 0.3, 0.12, 0.8) * (lLeft * 0.35));
        
        sig = spreadSig * (0.25 + lEnergy * 0.55);
        Out.ar(out, LeakDC.ar(sig));
    }).add;

    s.sync;

    ~drone = Synth(\conductorDrone, [
        \baseFreq, 65.4,
        \cutoff, 600,
        \res, 0.8,
        \pan, 0.0,
        \span, 0.5,
        \leftElev, 0.2,
        \energy, 0.1
    ]);

    // -------------------------------------------------------------------------
    // 5. OSC Handlers: Dual-Hand Messages
    // -------------------------------------------------------------------------

    // Strike Event (0=Left, 1=Right, 2=Dual/Tutti)
    OSCdef(\onIctus, { |msg|
        var intensity = msg[1];
        var axis = msg[2];
        var handType = msg[3]; // 0=left, 1=right, 2=dual
        
        if(handType == 0, {
            // Left Hand Gong Strike
            Synth(\leftHandStrike, [
                \freq, (80.0 * (1.0 + axis * 0.8)).clip(45, 240),
                \decay, (0.8 + intensity * 0.8).clip(0.3, 3.0),
                \amp, (0.3 + intensity * 0.5).clip(0.1, 1.0),
                \pan, -0.4
            ]);
            (">>> LEFT HAND GONG: Intensity=" ++ intensity.round(0.01)).postln;
        });

        if(handType == 1, {
            // Right Hand Chime Strike
            Synth(\rightHandStrike, [
                \freq, (220.0 * (1.0 + axis * 1.2)).clip(110, 880),
                \decay, (0.4 + intensity * 0.6).clip(0.1, 2.0),
                \amp, (0.3 + intensity * 0.5).clip(0.1, 1.0),
                \pan, (axis * 1.6 - 0.8).clip(-0.8, 0.8)
            ]);
            (">>> RIGHT HAND CHIME: Intensity=" ++ intensity.round(0.01)).postln;
        });

        if(handType == 2, {
            // Dual Strike (Tutti Downbeat)
            Synth(\tuttiStrike, [\amp, (0.5 + intensity * 0.5).clip(0.3, 1.2)]);
            (">>> DUAL TUTTI STRIKE! <<<").postln;
        });
    }, '/conductor/ictus');

    // Continuous Flow: [ry, rx, ly, span]
    OSCdef(\onMorph, { |msg|
        var ry = msg[1];   // Right hand elevation -> Cutoff
        var rx = msg[2];   // Right hand lateral -> Pan
        var ly = msg[3];   // Left hand elevation -> Expression/Resonance
        var span = msg[4]; // Dual hand distance -> Stereo expansion
        
        var cutoff = (200.0 + (ry * 1400.0)).clip(80, 16000);
        var pan = (rx * 2.0 - 1.0).clip(-1.0, 1.0);
        var res = (0.5 + (ly * 2.5)).clip(0.2, 3.5);
        var dSpan = span.clip(0.1, 1.5);

        ~drone.set(
            \cutoff, cutoff,
            \pan, pan,
            \res, res,
            \leftElev, ly.clip(0.0, 1.0),
            \span, dSpan
        );
    }, '/conductor/morph');

    // Energy & Surge
    OSCdef(\onTension, { |msg|
        var energy = msg[1];
        var flash = msg[2];
        ~drone.set(\energy, energy.clip(0.0, 3.0));
    }, '/conductor/tension');

    "Dual-Hand Conductor Synth Ready.".postln;
});
