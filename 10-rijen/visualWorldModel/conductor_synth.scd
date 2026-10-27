// =============================================================================
// conductor_synth.scd - JITLib / NodeProxy Native Gesture Conductor (KOF)
// Designed specifically for ProxySpace & NetProxy environments:
// - Real-time zero latency: overrides s.latency to 0.02s (20ms instead of 500ms!)
// - Native NodeProxy ~conductorFlow with immediate JITLib .set() modulation
// - Instantaneous transient modal strike synthesis for conducting Ictus
// =============================================================================

thisProcess.openUDPPort(57120);

// Override server latency for live gestural conduction (no 500ms backlog!)
s.latency = 0.02;

(">>> NodeProxy Conductor Initializing on port 57120 (s.latency=" ++ s.latency ++ ")").postln;

s.waitForBoot({
    // If not already in a ProxySpace, push current server
    if(currentEnvironment.isKindOf(ProxySpace).not) {
        p = ProxySpace.push(s);
    };

    // -------------------------------------------------------------------------
    // 1. Transient Modal Strike SynthDef (Independent of ProxySpace environment)
    // -------------------------------------------------------------------------
    SynthDef(\ictusStrike, { |freq = 220, decay = 0.5, amp = 0.7, pan = 0.0, brightness = 1.0|
        var excitation, freqs, ringTimes, modal, sig;
        
        // Fast analog transient impulse
        excitation = Decay2.ar(Impulse.ar(0), 0.0005, 0.008) * WhiteNoise.ar(0.6)
                   + (Dust2.ar(80) * 0.1);
        
        // Tuned resonant chime frequencies
        freqs = [freq, freq * 1.5, freq * 2.01, freq * 2.76, freq * 3.45, freq * 4.2];
        ringTimes = [decay, decay * 0.7, decay * 0.5, decay * 0.35, decay * 0.2, decay * 0.1];
        
        modal = Ringz.ar(excitation, freqs, ringTimes).sum;
        modal = LPF.ar(modal, (freq * 6 * brightness).clip(200, 18000));
        
        sig = modal * amp;
        sig = sig + (CombN.ar(sig, 0.2, 0.07, 0.4) * 0.3);
        
        DetectSilence.ar(sig, amp: 0.0001, time: 0.05, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 2. NodeProxy: Continuous Conductor Flow
    // -------------------------------------------------------------------------
    ~conductorFlow.ar(2);
    ~conductorFlow.fadeTime = 0.05;

    ~conductorFlow = { |pitch = 110, cutoff = 1200, pan = 0.0, res = 1.2, energy = 0.2, span = 0.5|
        var lPitch = Lag.kr(pitch, 0.03);
        var lCutoff = Lag.kr(cutoff, 0.03);
        var lPan = Lag.kr(pan, 0.03);
        var lRes = Lag.kr(res, 0.04);
        var lEnergy = Lag.kr(energy, 0.04);
        
        // Sub-bass foundation (soars with hand height)
        var sub = SinOsc.ar(lPitch * 0.5) * 0.6;
        
        // Dual morphing oscillators
        var osc1 = VarSaw.ar(lPitch, 0, (0.1 + lEnergy * 0.5).clip(0.05, 0.95)) * 0.4;
        var osc2 = Pulse.ar(lPitch * 1.005, (0.2 + lEnergy * 0.4).clip(0.1, 0.9)) * 0.35;
        
        var mixed = osc1 + osc2 + sub;
        
        // Resonant Moog filter
        var filtered = MoogFF.ar(mixed, lCutoff.clip(60, 16000), lRes.clip(0.2, 3.8));
        
        // Overdrive saturation
        var saturated = (filtered * (1.0 + lEnergy * 2.5)).tanh;
        
        var sig = saturated * (0.2 + (lEnergy * 0.65)).clip(0.08, 1.0);
        
        Pan2.ar(sig, lPan);
    };

    ~conductorFlow.play;

    // -------------------------------------------------------------------------
    // 3. OSC Listeners on Port 57120
    // -------------------------------------------------------------------------

    // A. Continuous Morphing: [yElev, xPan, energy, span]
    OSCdef(\onMorph, { |msg|
        var yElev = msg[1].asFloat;    // 0.0 (low) to 1.0 (high)
        var xPan = msg[2].asFloat;     // -1.0 (left) to +1.0 (right)
        var energy = msg[3].asFloat;   // 0.0 to 3.0+ (speed)
        var span = msg[4].asFloat;     // 0.0 to 1.5 (distance)
        
        // 4-octave pitch sweep (55 Hz A1 -> 880 Hz A5)
        var pitchHz = (55.0 * (2.0 ** (yElev * 4.0))).clip(45, 1200);
        
        // 6-octave filter sweep (100 Hz -> 12,000 Hz)
        var cutoffHz = (100.0 * (2.0 ** (yElev * 6.5))).clip(80, 16000);
        
        var panVal = xPan.clip(-1.0, 1.0);
        var resVal = (0.5 + (span * 2.0)).clip(0.2, 3.6);
        var energyVal = energy.clip(0.0, 3.0);

        // Native NodeProxy parameter update
        ~conductorFlow.set(
            \pitch, pitchHz,
            \cutoff, cutoffHz,
            \pan, panVal,
            \res, resVal,
            \energy, energyVal
        );
    }, '/conductor/morph', recvPort: 57120);

    // B. The Ictus Strike (Accent on hand flick / snap)
    OSCdef(\onIctus, { |msg|
        var intensity = msg[1].asFloat;
        var xPos = msg[2].asFloat;
        var yPos = msg[3].asFloat;
        
        var freq = (110.0 * (2.0 ** (yPos * 2.5))).clip(65, 880);
        var decay = (0.3 + intensity * 0.5).clip(0.15, 2.0);
        var amp = (0.4 + intensity * 0.4).clip(0.2, 1.0);
        var pan = (xPos * 2.0 - 1.0).clip(-1.0, 1.0);
        
        // Direct Synth allocation (safe from ProxySpace symbol collisions)
        Synth(\ictusStrike, [
            \freq, freq,
            \decay, decay,
            \amp, amp,
            \pan, pan,
            \brightness, (0.8 + intensity).clip(0.4, 2.5)
        ], s);
        
        (">>> ICTUS STRIKE: Freq=" ++ freq.round(1) ++ " Hz | Pan=" ++ pan.round(0.01)).postln;
    }, '/conductor/ictus', recvPort: 57120);

    "=========================================================".postln;
    "  NodeProxy Conductor Ready (~conductorFlow active)".postln;
    "=========================================================".postln;
});
