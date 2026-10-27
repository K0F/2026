// =============================================================================
// conductor_synth.scd - SuperCollider Gesture-Driven Resonant Synthesizer
// Captures optical gestures into sonically significant moments:
// 1. Ictus Strike: Sharp acceleration reversals excite modal acoustic resonators
// 2. Conductor Flow: Continuous morphing wavetable drone mapped to latent manifold (z)
// 3. Epistemic Surprise: Prediction error drives non-linear FM sideband dissonance
// 4. Fermata: Stillness allows subterranean sub-bass fundamentals to bloom
// =============================================================================

s.waitForBoot({
    "=========================================================".postln;
    "  GESTURE CONDUCTOR SYNTHESIZER INITIALIZED (KOF)".postln;
    "  Listening for OSC on UDP port 57120...".postln;
    "=========================================================".postln;

    // -------------------------------------------------------------------------
    // 1. SynthDef: The Ictus Strike (Modal Impulses & Transient Accents)
    // -------------------------------------------------------------------------
    SynthDef(\ictusStrike, { |freq = 180, decay = 0.8, amp = 0.5, pan = 0.0, brightness = 1.0|
        var trigger, excitation, freqs, ringTimes, modal, sig;
        
        // Analog crackle + bandlimited impulse
        excitation = Decay2.ar(Impulse.ar(0), 0.001, 0.015) * WhiteNoise.ar(0.3)
                   + (Dust2.ar(120) * 0.1);
        
        // Tuned resonant modal frequencies (metallic bell / membrane resonance)
        freqs = [freq, freq * 1.58, freq * 2.24, freq * 2.89, freq * 3.42, freq * 4.12];
        ringTimes = [decay, decay * 0.7, decay * 0.5, decay * 0.35, decay * 0.2, decay * 0.1];
        
        modal = Ringz.ar(excitation, freqs, ringTimes).sum;
        modal = LPF.ar(modal, (freq * 8 * brightness).clip(200, 18000));
        
        sig = modal * amp;
        sig = sig + (CombN.ar(sig, 0.2, 0.08, 0.6) * 0.2); // Spatial reverberation
        
        DetectSilence.ar(sig, amp: 0.0001, time: 0.1, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 2. SynthDef: Continuous Conductor Flow (Latent Manifold Drone)
    // -------------------------------------------------------------------------
    SynthDef(\conductorFlow, { |out = 0, baseFreq = 55, cutoff = 600, pan = 0.0, harmonicDensity = 0.5, energy = 0.2, surprise = 0.0|
        var osc1, osc2, sub, mixed, filtered, fmMod, sig;
        
        // Lagged smooth controls
        var lCutoff = Lag.kr(cutoff, 0.08);
        var lPan = Lag.kr(pan, 0.08);
        var lDensity = Lag.kr(harmonicDensity, 0.1);
        var lEnergy = Lag.kr(energy, 0.12);
        var lSurprise = Lag.kr(surprise, 0.05);
        
        // Subterranean sub-bass (Fermata bloom in stillness)
        sub = SinOsc.ar(baseFreq * 0.5) * (1.0 - (lEnergy * 0.6)).clip(0.1, 1.0);
        
        // Non-linear FM modulation driven by Epistemic Surprise
        fmMod = SinOsc.ar(baseFreq * 3.14) * (lSurprise * 400.0);
        
        // Dual morphing oscillators (Saw to Pulse with harmonic enrichment)
        osc1 = VarSaw.ar(baseFreq + fmMod, 0, lDensity.clip(0.01, 0.99));
        osc2 = Pulse.ar(baseFreq * 1.004 + (fmMod * 0.5), lDensity.clip(0.1, 0.9));
        
        mixed = (osc1 * 0.4) + (osc2 * 0.3) + (sub * 0.5);
        
        // Dynamic resonant filter tracked to vertical hand elevation
        filtered = MoogFF.ar(mixed, lCutoff.clip(80, 16000), (lEnergy * 2.5).clip(0.2, 3.2));
        
        sig = filtered * (0.2 + (lEnergy * 0.5));
        sig = LeakDC.ar(sig);
        
        Out.ar(out, Pan2.ar(sig, lPan));
    }).add;

    s.sync;

    // Start continuous drone instance
    ~drone = Synth(\conductorFlow, [
        \baseFreq, 65.4, // C2
        \cutoff, 500,
        \pan, 0.0,
        \harmonicDensity, 0.3,
        \energy, 0.1,
        \surprise, 0.0
    ]);

    // -------------------------------------------------------------------------
    // 3. OSC Dispatchers (Direct from Python Gesture Engine)
    // -------------------------------------------------------------------------

    // A. The Ictus Accent (Impulse strike at gesture inflection points)
    OSCdef(\onIctus, { |msg|
        var intensity = msg[1];
        var axis = msg[2];
        var freq = (110.0 * (1.0 + (axis * 1.5))).clip(55, 880);
        var decay = (0.3 + (intensity * 1.2)).clip(0.1, 3.0);
        var amp = (0.2 + (intensity * 0.6)).clip(0.1, 1.0);
        
        Synth(\ictusStrike, [
            \freq, freq,
            \decay, decay,
            \amp, amp,
            \pan, (axis * 1.6 - 0.8).clip(-1.0, 1.0),
            \brightness, (0.5 + intensity).clip(0.3, 2.5)
        ]);
        
        (">>> ICTUS STRIKE: Intensity=" ++ intensity.round(0.01) ++ " Freq=" ++ freq.round(1) ++ " Hz").postln;
    }, '/conductor/ictus');

    // B. Continuous Latent Flow (z0..z3 macroscopic coordinates)
    OSCdef(\onMorph, { |msg|
        var z0 = msg[1]; // Elevation -> Filter Cutoff
        var z1 = msg[2]; // Lateral -> Panning
        var z2 = msg[3]; // Density -> Wave Shape
        var z3 = msg[4]; // Depth -> Base Pitch
        
        var cutoff = (200.0 + (z0.clip(-2.5, 2.5) + 2.5) * 600.0).clip(100, 14000);
        var pan = (z1 / 2.5).clip(-1.0, 1.0);
        var density = ((z2 + 2.5) / 5.0).clip(0.05, 0.95);
        var baseFreq = (55.0 * (1.0 + ((z3 + 2.0) * 0.2))).clip(40, 180);

        ~drone.set(
            \cutoff, cutoff,
            \pan, pan,
            \harmonicDensity, density,
            \baseFreq, baseFreq
        );
    }, '/conductor/morph');

    // C. Kinetic Energy & Epistemic Surprise
    OSCdef(\onTension, { |msg|
        var energy = msg[1];
        var surprise = msg[2];
        
        ~drone.set(
            \energy, energy.clip(0.0, 2.0),
            \surprise, surprise.clip(0.0, 3.0)
        );
    }, '/conductor/tension');

    "Gesture Conductor Ready.".postln;
});
