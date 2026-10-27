// =============================================================================
// Neuron.pde - Biophysical Izhikevich Spiking Model with Neuromodulation
// Implements authentic biological firing patterns:
// - Regular Spiking (RS) excitatory pyramidal neurons
// - Fast Spiking (FS) inhibitory GABAergic interneurons
// - Intrinsically Bursting (IB) pacemaker units
// Coupled with spatial 3D Euclidean coordinates & tonic field modulation
// =============================================================================

class Neuron {
  int id;
  PVector pos;        // 3D Euclidean position (-350 to +350)
  PVector screenPos;  // Projected 2D screen coordinate
  PVector vel;
  
  // Izhikevich Dynamical System Parameters:
  // v' = 0.04*v^2 + 5*v + 140 - u + I
  // u' = a*(b*v - u)
  float v; // Membrane potential (mV)
  float u; // Membrane recovery variable
  
  float a, b, c, d; // Phenotype parameters
  boolean isInhibitory;
  boolean isPacemaker;
  
  boolean isSpiking = false;
  long lastSpikeFrame = -100;
  int spikeCount = 0;
  
  // Metabolic ATP reserve & Adaptation
  float metabolicATP = 1.0;
  
  // Synaptic Conductances (AMPA excitatory vs GABA inhibitory)
  float gAMPA = 0.0;
  float gGABA = 0.0;
  
  ArrayList<Synapse> outSynapses = new ArrayList<Synapse>();
  
  Neuron(int id, float x, float y, float z, boolean inhibitory, boolean pacemaker) {
    this.id = id;
    this.pos = new PVector(x, y, z);
    this.screenPos = new PVector(x, y);
    this.vel = PVector.random3D().mult(0.06);
    this.isInhibitory = inhibitory;
    this.isPacemaker = pacemaker;
    
    // Phenotypic tuning:
    if (isInhibitory) {
      // Fast Spiking (FS) Interneuron
      a = 0.10;
      b = 0.20;
      c = -65.0;
      d = 2.0;
    } else if (isPacemaker) {
      // Intrinsically Bursting (IB)
      a = 0.02;
      b = 0.20;
      c = -55.0;
      d = 4.0;
    } else {
      // Regular Spiking (RS) Pyramidal Neuron
      a = 0.02;
      b = 0.20;
      c = -65.0;
      d = 8.0;
    }
    
    v = c + random(-5, 5);
    u = b * v;
  }
  
  void update(float sensoryCurrent, float tonicFieldModulation) {
    metabolicATP = min(1.0, metabolicATP + 0.0025);
    
    // Fast synaptic conductance decay
    gAMPA *= 0.82;
    gGABA *= 0.78;
    
    // Total synaptic input current
    float I_syn = (gAMPA * 22.0) - (gGABA * 28.0);
    
    // Total driving current = Synaptic + Sensory + Tonic Neuromodulatory Field + Spontaneous baseline
    float I = I_syn + sensoryCurrent * metabolicATP + tonicFieldModulation * 6.0;
    if (isPacemaker) {
      I += 3.5; // Tonic pacemaker drive
    }
    
    // Two-step numerical integration for Izhikevich model stability (0.5 ms sub-steps)
    for (int step = 0; step < 2; step++) {
      v += 0.5 * (0.04 * v * v + 5.0 * v + 140.0 - u + I);
    }
    u += a * (b * v - u);
    
    // Check Action Potential Peak (+30 mV)
    if (v >= 30.0) {
      fire();
      v = c;
      u += d;
    } else {
      isSpiking = false;
    }
    
    // Subtle Brownian drift in 3D volume
    pos.add(vel);
    if (pos.x < -360 || pos.x > 360) vel.x *= -1;
    if (pos.y < -280 || pos.y > 280) vel.y *= -1;
    if (pos.z < -200 || pos.z > 200) vel.z *= -1;
  }
  
  void fire() {
    isSpiking = true;
    lastSpikeFrame = frameCount;
    spikeCount++;
    metabolicATP = max(0.05, metabolicATP - 0.055);
    
    for (Synapse syn : outSynapses) {
      syn.propagateSpike(isInhibitory ? -1.0 : 1.0);
    }
  }
  
  void deliverSynapticInput(float weight, float polarity) {
    if (polarity > 0) {
      gAMPA += weight;
    } else {
      gGABA += weight;
    }
  }
  
  void injectCurrent(float current) {
    v += current;
  }
  
  void project(float rotX, float rotY, float centerX, float centerY, float zoom) {
    float cosY = cos(rotY), sinY = sin(rotY);
    float cosX = cos(rotX), sinX = sin(rotX);
    
    float x1 = pos.x * cosY + pos.z * sinY;
    float z1 = -pos.x * sinY + pos.z * cosY;
    
    float y1 = pos.y * cosX - z1 * sinX;
    float z2 = pos.y * sinX + z1 * cosX;
    
    float fov = 680.0;
    float scale = fov / (fov + z2 + 420.0) * zoom;
    
    screenPos.x = centerX + x1 * scale;
    screenPos.y = centerY + y1 * scale;
  }
  
  void draw() {
    float normV = constrain((v - (-75.0)) / (30.0 - (-75.0)), 0.0, 1.0);
    
    if (isSpiking) {
      noStroke();
      if (isInhibitory) {
        fill(240, 50, 90, 240); // GABAergic magenta
      } else if (isPacemaker) {
        fill(50, 240, 210, 240); // Pacemaker cyan
      } else {
        fill(255, 204, 17, 250); // Pyramidal amber
      }
      rect(screenPos.x - 3, screenPos.y - 3, 6, 6);
      fill(255);
      rect(screenPos.x - 1, screenPos.y - 1, 2, 2);
    } else {
      noFill();
      if (isInhibitory) {
        stroke(170, 35, 75, 30 + normV * 140);
      } else {
        stroke(35, 115, 135, 30 + normV * 140);
      }
      rect(screenPos.x - 2, screenPos.y - 2, 4, 4);
      stroke(190, 215, 235, 120);
      point(screenPos.x, screenPos.y);
    }
  }
}
