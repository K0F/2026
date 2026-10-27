// =============================================================================
// kofsNeuralWorks.pde - Integrated 2007-2026 Processing Neuro-Laboratory
// Full 60-Second Neuromorphic Symphony: Dense 3D Lattice, Harmonic Manifold &
// Deeply Responsive Presidential Speech Engine
//
// Synthesizes:
// - 2010 (neuronsParraler3D): 3D spatial Euclidean topology, Peasy-style orbiting,
//   dense thousands-of-connections mesh, traveling signal packets (#ffcc11)
// - 2020 (pulseCube): Volumetric lattice dynamics, continuous rotX/rotY precession
// - 2007 (neuroSys): Biophysical membrane dynamics, refractory hyperpolarization
// - 2009 (workingNeuralNet & Neural32): Continuous coordinate manifold backpropagation
// - 2011 (asemicNeuralWriting): Low-alpha phosphor filaments, STDP plasticity
// - 2026 (FlyBrain): Dale's principle (80% Exc / 20% Inh) & homeostatic ATP
// - 2014-2016 (markovChainGenerator & markovsTTS): One-Button Presidential Speech Engine
// =============================================================================

import java.io.File;

ArrayList<Neuron> neurons = new ArrayList<Neuron>();
ArrayList<Synapse> synapses = new ArrayList<Synapse>();
NeuralField field;
VectorScope scope;
PresidentialMarkovEngine speech;

PFont font;
boolean autoTrain = true;
int totalSpikesThisSecond = 0;
int spikeRateHz = 0;
int lastSecondFrame = 0;

// 3D Volumetric Camera Angles
float rotX = 0.30;
float rotY = -0.50;
float targetRotX = 0.30;
float targetRotY = -0.50;
float zoom = 1.0;
float targetZoom = 1.0;
boolean isOrbiting = false;
float lastMouseX, lastMouseY;

// Electrode Mode: 1 = DC Depolarization, 2 = 40Hz Gamma Pacemaker, 3 = GABA Clamp
int electrodeMode = 1;

// Render Mode Configuration (Full 60 Seconds @ 60 FPS = 3,600 Frames)
boolean recordFrames = false;
int maxRenderFrames = 3600;
String renderDir = "/mnt/ssd/render/kofsNeuralWorks/frames";

void setup() {
  size(1280, 840);
  surface.setTitle("kofsNeuralWorks :: Dense 3D Spiking Laboratory (kof)");
  frameRate(60);
  
  File renderTrigger = new File("/mnt/ssd/render/kofsNeuralWorks/.render_mode");
  if (renderTrigger.exists() || (args != null && args.length > 0 && args[0].equals("--render"))) {
    recordFrames = true;
    println(">>> FULL 60-SECOND DENSE VIDEO RENDER MODE ACTIVATED <<<");
    println("Output: " + renderDir + "/frame_####.png | Max frames: " + maxRenderFrames);
  }
  
  try {
    font = createFont("Monospaced", 8);
  } catch (Exception e) {
    font = createFont("Courier", 8);
  }
  textFont(font, 8);
  
  field = new NeuralField();
  scope = new VectorScope();
  
  // Initialize Dense 3D Volumetric Lattice (360 Spatially Embedded Neurons)
  initDenseLattice(360, 75.0);
  
  // Initialize Responsive Presidential Speech Engine
  speech = new PresidentialMarkovEngine(neurons.size());
  
  background(0);
}

void initDenseLattice(int count, float connectRadius) {
  neurons.clear();
  synapses.clear();
  
  // 1. Distribute Neurons in 3D Ellipsoid Volume (2010 neuronsParraler3D)
  for (int i = 0; i < count; i++) {
    float u = random(1.0);
    float v = random(1.0);
    float theta = u * TWO_PI;
    float phi = acos(2.0 * v - 1.0);
    float r = pow(random(1.0), 0.52) * 315.0;
    
    float x = r * sin(phi) * cos(theta);
    float y = r * sin(phi) * sin(theta) * 0.72;
    float z = r * cos(phi) * 0.58;
    
    float phenoRoll = random(1.0);
    boolean inhibitory = (phenoRoll < 0.20);
    boolean pacemaker = (!inhibitory && phenoRoll > 0.95);
    
    neurons.add(new Neuron(i, x, y, z, inhibitory, pacemaker));
  }
  
  // 2. Form Dense Spatial Synaptic Mesh (3D Euclidean Radius Check)
  for (Neuron pre : neurons) {
    for (Neuron post : neurons) {
      if (pre == post) continue;
      float d = PVector.dist(pre.pos, post.pos);
      if (d < connectRadius && random(1.0) < 0.36) {
        float initialWeight = random(0.25, 0.70);
        Synapse s = new Synapse(pre, post, initialWeight);
        synapses.add(s);
        pre.outSynapses.add(s);
      }
    }
  }
}

void draw() {
  // Phosphor visual persistence (analog CRT decay)
  noStroke();
  fill(0, 52);
  rect(0, 0, width, height);
  
  // Measure Spike Rate (Hz)
  if (frameCount - lastSecondFrame >= 60) {
    spikeRateHz = totalSpikesThisSecond;
    totalSpikesThisSecond = 0;
    lastSecondFrame = frameCount;
  }
  
  // --- CINEMATIC 60-SECOND CHOREOGRAPHY (Render Mode) ---
  float viewportCenterX = 440.0;
  float viewportCenterY = 340.0;
  float probeX = mouseX;
  float probeY = mouseY;
  boolean probeActive = mousePressed && mouseButton == LEFT;
  
  if (!isOrbiting) {
    targetRotY += 0.0035;
    targetRotX = 0.28 + sin(frameCount * 0.004) * 0.12;
  }
  
  if (recordFrames) {
    // Act Choreography across 3,600 frames:
    if (frameCount <= 600) {
      // Act 1 (0-10s): Awakening & Natural Precession
      targetZoom = 1.0;
      probeActive = false;
    } else if (frameCount <= 1400) {
      // Act 2 (10-23s): Focused DC Depolarization Sweep
      float t = (frameCount - 600) * 0.025;
      probeX = viewportCenterX + cos(t * 0.8) * 220 + sin(t * 1.6) * 50;
      probeY = viewportCenterY + sin(t) * 150 + cos(t * 1.3) * 40;
      probeActive = true;
      electrodeMode = 1;
      targetZoom = 1.05;
    } else if (frameCount <= 2200) {
      // Act 3 (23-36s): 40Hz Gamma Burst Train & Cortical Resonance
      float t = (frameCount - 1400) * 0.03;
      probeX = viewportCenterX + sin(t) * 180;
      probeY = viewportCenterY + cos(t * 1.2) * 130;
      probeActive = true;
      electrodeMode = 2;
      targetZoom = 1.15;
    } else if (frameCount <= 3000) {
      // Act 4 (36-50s): Deep 3D Flythrough & Fast Precession
      targetRotY += 0.008;
      targetRotX = 0.40 + cos(frameCount * 0.006) * 0.20;
      targetZoom = 1.25 + sin(frameCount * 0.01) * 0.15;
      probeActive = false;
    } else {
      // Act 5 (50-60s): GABA Clamp & Peaceful Phosphor Decay
      float t = (frameCount - 3000) * 0.02;
      probeX = viewportCenterX;
      probeY = viewportCenterY;
      probeActive = (frameCount < 3400);
      electrodeMode = 3;
      targetZoom = 1.0;
    }
  }
  
  rotX += (targetRotX - rotX) * 0.08;
  rotY += (targetRotY - rotY) * 0.08;
  zoom += (targetZoom - zoom) * 0.05;
  
  // Project all 3D neurons to 2D viewport
  for (Neuron n : neurons) {
    n.project(rotX, rotY, viewportCenterX, viewportCenterY, zoom);
  }
  
  // Update Speech Engine coupled to neural firing rate
  speech.update(neurons, spikeRateHz);
  
  // --- 1. SENSORY CURRENT ---
  float sensoryCurrent = 0.0;
  if (probeActive) {
    if (electrodeMode == 1) sensoryCurrent = 16.0;
    else if (electrodeMode == 2) sensoryCurrent = (sin(frameCount * 0.65) > 0.0) ? 26.0 : 0.0;
    else if (electrodeMode == 3) sensoryCurrent = -22.0;
  }
  
  // --- 2. UPDATE DENSE NEURAL DYNAMICS ---
  float dipoleX = 0.0;
  float dipoleY = 0.0;
  float totalATP = 0.0;
  int activeSpikeCount = 0;
  
  for (Neuron n : neurons) {
    float stim = 0.0;
    float dProbe = dist(n.screenPos.x, n.screenPos.y, probeX, probeY);
    if (dProbe < 72.0 && probeActive) {
      stim = sensoryCurrent * (1.0 - dProbe / 72.0);
    }
    
    // Spontaneous pacemaker noise
    if (random(1.0) < 0.008) {
      stim += random(3.0, 7.0);
    }
    
    // Closed-Loop: Sample neuromodulatory potential from coordinate field
    float normU = constrain((n.pos.x + 350.0) / 700.0, 0.0, 1.0);
    float normV = constrain((n.pos.y + 280.0) / 560.0, 0.0, 1.0);
    float tonicField = field.sampleAt(normU, normV) - 0.5;
    
    n.update(stim, tonicField);
    if (n.isSpiking) {
      totalSpikesThisSecond++;
      activeSpikeCount++;
    }
    totalATP += n.metabolicATP;
    
    float normV_mV = (n.v - (-75.0)) / (30.0 - (-75.0));
    dipoleX += (n.pos.x / 320.0) * normV_mV;
    dipoleY += (n.pos.y / 240.0) * normV_mV;
  }
  
  // Update Synapses & prune
  for (int i = synapses.size() - 1; i >= 0; i--) {
    Synapse s = synapses.get(i);
    s.update();
    if (s.markedForPruning) {
      s.pre.outSynapses.remove(s);
      synapses.remove(i);
    }
  }
  
  // Push Dipole to Vector Oscilloscope (XYScope bridge)
  dipoleX = constrain(dipoleX * 0.14, -1.0, 1.0);
  dipoleY = constrain(dipoleY * 0.14, -1.0, 1.0);
  scope.pushSample(dipoleX, dipoleY, (float)activeSpikeCount / neurons.size());
  
  // --- 3. CLOSED-LOOP MANIFOLD BACKPROP TRAINING ---
  if (autoTrain) {
    for (int step = 0; step < 12; step++) {
      float u = random(1.0);
      float v = random(1.0);
      float target = (sin(u * 6.28 + dipoleX * 3.14) * cos(v * 6.28 + dipoleY * 3.14) + 1.0) * 0.5;
      field.trainStep(u, v, target);
    }
  }
  
  // --- 4. RENDER DENSE VIEWPORT ---
  
  // Main Viewport Frame
  stroke(22, 28, 36);
  noFill();
  rect(30, 30, 820, 620);
  
  // Draw all Dense Axonal Filaments
  for (Synapse s : synapses) {
    s.draw();
  }
  
  // Draw all Dense Somatic Nodes
  for (Neuron n : neurons) {
    n.draw();
  }
  
  // Draw Floating 3D Word Labels directly above active neurons
  speech.render3DLabels(neurons);
  
  // Draw Sensory Electrode Reticle
  if (probeActive) {
    stroke(255, 200, 50, 150);
    noFill();
    rect(probeX - 6, probeY - 6, 12, 12);
    line(probeX - 12, probeY, probeX + 12, probeY);
    line(probeX, probeY - 12, probeX, probeY + 12);
    fill(220);
    String modeName = (electrodeMode == 1 ? "DC DEPOLARIZATION (+16 mV)" : (electrodeMode == 2 ? "GAMMA BURST TRAIN (40 Hz)" : "GABA CLAMP (-22 mV)"));
    text("PROBE: " + modeName, probeX + 16, probeY + 3);
  }
  
  // Right Side Panels
  float panelX = 870;
  
  // 1. Latent Coordinate Field Panel (Fourier SIREN)
  fill(120, 140, 160);
  text("HARMONIC COORDINATE MANIFOLD [FOURIER ENCODING]", panelX, 42);
  field.renderField(panelX, 50, 380, 220, 32);
  
  // 2. Vector Oscilloscope CRT Panel (XYScope bridge)
  fill(120, 140, 160);
  text("DIPOLE VECTOR SCOPE [XYSCOPE BRIDGE]", panelX, 292);
  scope.render(panelX, 300, 380, 210);
  
  // 3. Laboratory Telemetry HUD (Bottom Right)
  fill(4, 6, 8, 220);
  stroke(22, 28, 36);
  rect(panelX, 530, 380, 120);
  
  fill(80, 220, 160);
  text("TELEMETRY :: CLOSED-LOOP NEURAL DYNAMICS", panelX + 12, 548);
  
  fill(140, 160, 180);
  text(String.format("Spike Rate:     %d Hz (Active Spikes: %d)", spikeRateHz, activeSpikeCount), panelX + 12, 566);
  text(String.format("Dense Topology: %d Neurons | %d Synapses", neurons.size(), synapses.size()), panelX + 12, 580);
  text(String.format("Mean ATP Level: %.1f%%", (totalATP / neurons.size()) * 100.0), panelX + 12, 594);
  text(String.format("Manifold Loss:  MSE %.6f (Step %d)", field.currentMSE, field.trainingSteps), panelX + 12, 608);
  text(String.format("3D Camera:      rotX: %.2f  rotY: %.2f  zoom: %.2f", rotX, rotY, zoom), panelX + 12, 622);
  text(String.format("Markov State:   Node %d / %d  Cadence: %d fps", speech.currentState, speech.nodes.size(), speech.currentCadence), panelX + 12, 636);
  
  // --- 5. ONE-BUTTON PRESIDENTIAL SPEECH CONSOLE HUD ---
  speech.renderHUD(30, 665, 1220, 95);
  
  // Bottom Terminal Status Line
  fill(4, 6, 8, 220);
  stroke(22, 28, 36);
  rect(30, 775, 1220, 50);
  
  fill(240, 205, 50);
  text("KOFS-NEURAL-WORKS :: 2007-2026 UNIFIED KNOWLEDGE LABORATORY (kof)", 45, 792);
  
  fill(110, 130, 150);
  if (recordFrames) {
    fill(255, 80, 80);
    text(String.format("RECORDING FULL-MINUTE MASTERPIECE: FRAME %04d / %04d (%.1f%%)", frameCount, maxRenderFrames, (float)frameCount / maxRenderFrames * 100.0), 45, 810);
  } else {
    text("[P]: TRIGGER SPEECH BURST   [L-CLICK]: Apply electrode   [R-CLICK DRAG]: Orbit 3D   [SPACE]: Toggle training   [1/2/3]: Mode", 45, 810);
  }
  
  // --- FRAME EXPORT FOR VIDEO RENDER ---
  if (recordFrames) {
    saveFrame(renderDir + "/frame_####.png");
    if (frameCount % 120 == 0) {
      println(String.format("Rendered %d / %d frames (%.1f%%) - %d sec / 60 sec", frameCount, maxRenderFrames, (float)frameCount / maxRenderFrames * 100.0, frameCount / 60));
    }
    if (frameCount >= maxRenderFrames) {
      println(">>> RENDER COMPLETE: 3,600 frames (60.0s) exported successfully. Exiting sketch. <<<");
      exit();
    }
  }
}

void mousePressed() {
  if (mouseButton == RIGHT) {
    isOrbiting = true;
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
  if (mouseButton == LEFT && mouseX >= 30 && mouseX <= 1250 && mouseY >= 665 && mouseY <= 760) {
    speech.triggerSpeechBurst();
  }
}

void mouseDragged() {
  if (mouseButton == RIGHT) {
    float dx = mouseX - lastMouseX;
    float dy = mouseY - lastMouseY;
    targetRotY += dx * 0.01;
    targetRotX -= dy * 0.01;
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
}

void mouseReleased() {
  if (mouseButton == RIGHT) {
    isOrbiting = false;
  }
}

void keyPressed() {
  if (key == 'p' || key == 'P') {
    speech.triggerSpeechBurst();
  } else if (key == ' ') {
    autoTrain = !autoTrain;
  } else if (key == '1') {
    electrodeMode = 1;
  } else if (key == '2') {
    electrodeMode = 2;
  } else if (key == '3') {
    electrodeMode = 3;
  } else if (key == 't' || key == 'T') {
    for (int i = 0; i < 64; i++) {
      float u = random(1.0);
      float v = random(1.0);
      float target = (sin(u * 6.28) * cos(v * 6.28) + 1.0) * 0.5;
      field.trainStep(u, v, target);
    }
  } else if (key == 'r' || key == 'R') {
    initDenseLattice(360, 75.0);
    background(0);
  } else if (key == 'c' || key == 'C') {
    for (Neuron n : neurons) {
      n.v = -75.0;
      n.u = n.b * n.v;
    }
    for (Synapse s : synapses) {
      s.activePulses.clear();
    }
  }
}
