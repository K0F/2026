// =============================================================================
// Synapse.pde - Dense Axonal Transmission Line with High-Throughput Pulses
// Pure Kof Aesthetic: Low-alpha negative contrast, crisp 1px lines, STDP
// Combines 2010 (neuronsParraler3D) high-density connectivity with STDP plasticity
// =============================================================================

class SpikePulse {
  float progress = 0.0;
  float speed;
  float polarity; // +1 excitatory, -1 inhibitory
  
  SpikePulse(float conductionSpeed, float pol) {
    this.speed = conductionSpeed;
    this.polarity = pol;
  }
}

class Synapse {
  Neuron pre;
  Neuron post;
  float weight;          // Synaptic weight [0.0 to 1.0]
  float conductionSpeed;
  
  ArrayList<SpikePulse> activePulses = new ArrayList<SpikePulse>();
  boolean markedForPruning = false;
  
  Synapse(Neuron pre, Neuron post, float initialWeight) {
    this.pre = pre;
    this.post = post;
    this.weight = initialWeight;
    float targetDist = PVector.dist(pre.pos, post.pos);
    this.conductionSpeed = constrain(8.0 / max(20.0, targetDist), 0.025, 0.12);
  }
  
  void propagateSpike(float polarity) {
    if (activePulses.size() < 4) {
      activePulses.add(new SpikePulse(conductionSpeed, polarity));
    }
  }
  
  void update() {
    // Propagate traveling action potential packets
    for (int i = activePulses.size() - 1; i >= 0; i--) {
      SpikePulse p = activePulses.get(i);
      p.progress += p.speed;
      
      if (p.progress >= 1.0) {
        post.deliverSynapticInput(weight, p.polarity);
        
        // Spike-Timing-Dependent Plasticity (STDP):
        long dt = post.lastSpikeFrame - pre.lastSpikeFrame;
        if (dt > 0 && dt < 8) {
          weight = min(1.0, weight + 0.03); // Potentiation
        } else if (dt < 0 && dt > -8) {
          weight = max(0.01, weight - 0.015); // Depression
        }
        activePulses.remove(i);
      }
    }
    
    // Slow synaptic decay / pruning in dense networks
    weight *= 0.99995;
    if (weight < 0.015 && activePulses.isEmpty()) {
      markedForPruning = true;
    }
  }
  
  void draw() {
    // Crisp 1px axonal filament (pure 2010 neuronsParraler3D low-alpha aesthetic)
    if (pre.isInhibitory) {
      stroke(150, 35, 65, 12 + weight * 55);
    } else {
      stroke(25, 95, 115, 12 + weight * 55);
    }
    strokeWeight(1);
    line(pre.screenPos.x, pre.screenPos.y, post.screenPos.x, post.screenPos.y);
    
    // Traveling pulse packets along the axon
    if (!activePulses.isEmpty()) {
      for (SpikePulse p : activePulses) {
        float px = lerp(pre.screenPos.x, post.screenPos.x, p.progress);
        float py = lerp(pre.screenPos.y, post.screenPos.y, p.progress);
        
        if (p.polarity < 0) {
          stroke(230, 50, 90, 220);
        } else {
          stroke(255, 215, 60, 240);
        }
        point(px, py);
      }
    }
  }
}
