// =============================================================================
// conductor_synth.scd - Dedicated Port 57130 Gesture Conductor Synthesizer
// Uses dedicated, collision-free UDP port 57130
// s.latency = nil (executes immediately with zero timestamp latency)
// =============================================================================

var port = 57130;
thisProcess.openUDPPort(port);
(">>> sclang OPENED DEDICATED UDP PORT: " ++ port).postln;

// Set latency to nil for immediate unbuffered execution
s.latency = nil;

s.waitForBoot({
    "=========================================================".postln;
    "  GESTURE CONDUCTOR SYNTHESIZER READY (PORT 57130)".postln;
    "=========================================================".postln;

    if(currentEnvironment.isKindOf(ProxySpace).not) {
        p = ProxySpace.push(s);
    };

    // -------------------------------------------------------------------------
    // 1. SynthDef: Ictus Strike (Transient Modal Resonator - Comfortably Leveled)
    // -------------------------------------------------------------------------
    SynthDef(\ictusStrike, { |freq = 220, decay = 0.5, amp = 0.18, pan = 0.0, brightness = 1.0|
        var excitation, freqs, ringTimes, modal, sig;
        
        excitation = Decay2.ar(Impulse.ar(0), 0.0005, 0.008) * WhiteNoise.ar(0.3)
                   + (Dust2.ar(60) * 0.05);
        
        freqs = [freq, freq * 1.5, freq * 2.01, freq * 2.76, freq * 3.45, freq * 4.2];
        ringTimes = [decay, decay * 0.7, decay * 0.5, decay * 0.35, decay * 0.2, decay * 0.1];
        
        // Ringz has massive resonant gain; scale down by 0.08 for headroom
        modal = Ringz.ar(excitation, freqs, ringTimes).sum * 0.08;
        modal = LPF.ar(modal, (freq * 5 * brightness).clip(200, 14000));
        
        sig = modal * amp;
        sig = sig + (CombN.ar(sig, 0.2, 0.06, 0.3) * 0.25);
        sig = Limiter.ar(sig, 0.3); // Safe ear protection ceiling
        
        DetectSilence.ar(sig, amp: 0.0001, time: 0.05, doneAction: 2);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // -------------------------------------------------------------------------
    // 2. NodeProxy: Continuous Conductor Flow (Soft, Warm, Musical Drone)
    // -------------------------------------------------------------------------
    ~conductorFlow.ar(2);
    ~conductorFlow.fadeTime = 0.02;

    ~conductorFlow = { |pitch = 110, cutoff = 1200, pan = 0.0, res = 1.0, energy = 0.2, span = 0.5, masterVol = 0.2|
        var lPitch = Lag.kr(pitch, 0.03);
        var lCutoff = Lag.kr(cutoff, 0.03);
        var lPan = Lag.kr(pan, 0.03);
        var lRes = Lag.kr(res, 0.04);
        var lEnergy = Lag.kr(energy, 0.04);
        
        var sub = SinOsc.ar(lPitch * 0.5) * 0.35;
        var osc1 = VarSaw.ar(lPitch, 0, (0.1 + lEnergy * 0.4).clip(0.05, 0.95)) * 0.25;
        var osc2 = Pulse.ar(lPitch * 1.005, (0.2 + lEnergy * 0.3).clip(0.1, 0.9)) * 0.2;
        
        var mixed = osc1 + osc2 + sub;
        var filtered = MoogFF.ar(mixed, lCutoff.clip(60, 14000), lRes.clip(0.1, 2.8));
        var saturated = (filtered * (1.0 + lEnergy * 1.8)).tanh;
        
        // Musical, controlled volume curve (safe & gentle)
        var sig = saturated * (0.05 + (lEnergy * 0.12)).clip(0.02, 0.22) * masterVol;
        sig = Limiter.ar(sig, 0.25); // Ceiling
        
        Pan2.ar(sig, lPan);
    };

    ~conductorFlow.play;

    // -------------------------------------------------------------------------
    // 3. OSCdef on Dedicated Port 57130
    // -------------------------------------------------------------------------

    // A. Continuous Morphing: [yElev, xPan, energy, span]
    // Listens on ALL open UDP ports (both 57120 and 57130)
    OSCdef(\onMorph, { |msg|
        var yElev = msg[1].asFloat;
        var xPan = msg[2].asFloat;
        var energy = msg[3].asFloat;
        var span = msg[4].asFloat;
        
        var pitchHz = (55.0 * (2.0 ** (yElev * 4.0))).clip(45, 1200);
        var cutoffHz = (100.0 * (2.0 ** (yElev * 6.5))).clip(80, 16000);
        var panVal = xPan.clip(-1.0, 1.0);
        var resVal = (0.5 + (span * 2.0)).clip(0.2, 3.6);
        var energyVal = energy.clip(0.0, 3.0);

        ~conductorFlow.set(
            \pitch, pitchHz,
            \cutoff, cutoffHz,
            \pan, panVal,
            \res, resVal,
            \energy, energyVal
        );
    }, '/conductor/morph');

    // B. The Ictus Strike
    OSCdef(\onIctus, { |msg|
        var intensity = msg[1].asFloat;
        var xPos = msg[2].asFloat;
        var yPos = msg[3].asFloat;
        
        var freq = (110.0 * (2.0 ** (yPos * 2.5))).clip(65, 880);
        var decay = (0.3 + intensity * 0.5).clip(0.15, 2.0);
        var amp = (0.08 + intensity * 0.12).clip(0.04, 0.22);
        var pan = (xPos * 2.0 - 1.0).clip(-1.0, 1.0);
        
        Synth(\ictusStrike, [
            \freq, freq,
            \decay, decay,
            \amp, amp,
            \pan, pan,
            \brightness, (0.8 + intensity).clip(0.4, 2.5)
        ], s);
        
        (">>> ICTUS STRIKE: Freq=" ++ freq.round(1) ++ " Hz | Pan=" ++ pan.round(0.01) ++ " | Int=" ++ intensity.round(0.01)).postln;
    }, '/conductor/ictus');

    "SuperCollider Conductor Ready (listening on ports 57120 and 57130).".postln;
});
