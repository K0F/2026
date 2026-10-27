// =============================================================================
// MarkovSpeech.pde - Highly Responsive Neural-Coupled Speech Generator
// LLM Precursor with Dynamic Neural Entrainment
//
// Features:
// - Dynamic Speech Cadence: Firing rate directly modulates verbal tempo
// - In-Situ 3D Semantic Projection: Spoken words float above their neural soma
// - Traveling Wave Induction: Token emission sparks cascading cortical waves
// - Expanded Presidential Corpus (Masaryk, Havel, Klaus, Zeman rhetorical synthesis)
// =============================================================================

class MarkovNode {
  int id;
  String token;
  ArrayList<Integer> targets = new ArrayList<Integer>();
  ArrayList<Float> baseWeights = new ArrayList<Float>();
  
  int boundNeuronId;
  float flashIntensity = 0.0;
  
  MarkovNode(int id, String token, int boundNeuronId) {
    this.id = id;
    this.token = token;
    this.boundNeuronId = boundNeuronId;
  }
  
  void addTransition(int targetId, float weight) {
    targets.add(targetId);
    baseWeights.add(weight);
  }
  
  int selectNext(ArrayList<Neuron> network) {
    if (targets.isEmpty()) return 0;
    
    float totalWeight = 0.0;
    float[] dynamicWeights = new float[targets.size()];
    
    for (int i = 0; i < targets.size(); i++) {
      int tId = targets.get(i);
      float w = baseWeights.get(i);
      
      if (tId >= 0 && tId < network.size()) {
        Neuron targetNeuron = network.get(tId);
        // Excitatory membrane potential drives choice probability
        float normV = constrain((targetNeuron.v - (-75.0)) / (30.0 - (-75.0)), 0.05, 3.0);
        w *= normV;
        if (targetNeuron.isSpiking) {
          w *= 4.0; // Spike bonus creates immediate attractor steering
        }
      }
      dynamicWeights[i] = w;
      totalWeight += w;
    }
    
    float roll = random(totalWeight);
    float accum = 0.0;
    for (int i = 0; i < targets.size(); i++) {
      accum += dynamicWeights[i];
      if (roll <= accum) {
        return targets.get(i);
      }
    }
    return targets.get(0);
  }
}

class PresidentialMarkovEngine {
  ArrayList<MarkovNode> nodes = new ArrayList<MarkovNode>();
  int currentState = 0;
  
  String currentWord = "";
  String generatedSpeech = "> ";
  ArrayList<String> speechHistory = new ArrayList<String>();
  
  boolean isGenerating = true; // Continuously generative
  int cadenceTimer = 0;
  int currentCadence = 10;
  
  PresidentialMarkovEngine(int totalNeurons) {
    buildPresidentialCorpus(totalNeurons);
  }
  
  void buildPresidentialCorpus(int totalNeurons) {
    String[] vocab = {
      "Vážení", "spoluobčané,", "stojíme", "na", "historické", "křižovatce.",
      "Naše", "země", "potřebuje", "odvahu,", "rozvahu", "a", "společenský", "smír.",
      "Svoboda", "a", "demokracie", "nejsou", "samozřejmostí,", "jsou", "každodenním", "závazkem.",
      "V", "této", "chvíli", "musíme", "překonat", "všechny", "vnitřní", "spory.",
      "Hospodářská", "síla", "a", "technologická", "tvořivost", "tvoří", "budoucnost.",
      "Důvěra", "v", "instituce", "pramení", "z", "čistého", "svědomí", "a", "práce.",
      "Pravda", "a", "láska", "musí", "zvítězit", "nad", "lží", "a", "nenávistí.",
      "Přeji", "vám", "pevné", "zdraví,", "naději", "a", "víru", "v", "naši", "vlast."
    };
    
    for (int i = 0; i < vocab.length; i++) {
      int neuronBinding = (i * 9) % totalNeurons;
      nodes.add(new MarkovNode(i, vocab[i], neuronBinding));
    }
    
    for (int i = 0; i < nodes.size(); i++) {
      MarkovNode n = nodes.get(i);
      // Sequential flow
      if (i + 1 < nodes.size()) {
        n.addTransition(i + 1, 0.70);
      } else {
        n.addTransition(0, 0.75); // Loop
      }
      
      // Dynamic rhetorical branches
      int j1 = (i + 3) % nodes.size();
      int j2 = (i + 7) % nodes.size();
      int j3 = (i + 12) % nodes.size();
      n.addTransition(j1, 0.18);
      n.addTransition(j2, 0.12);
      n.addTransition(j3, 0.10);
    }
  }
  
  void triggerSpeechBurst() {
    isGenerating = true;
    currentState = 0;
    generatedSpeech = "> ";
    cadenceTimer = currentCadence; // Immediate start
  }
  
  void update(ArrayList<Neuron> lattice, int globalSpikeRate) {
    // Dynamic Cadence: Excited neural network speeds up speaking tempo
    currentCadence = constrain(int(14.0 - (globalSpikeRate / 18.0)), 4, 22);
    
    // Decay flash highlights
    for (MarkovNode mn : nodes) {
      mn.flashIntensity *= 0.88;
    }
    
    if (!isGenerating) return;
    
    cadenceTimer++;
    if (cadenceTimer >= currentCadence) {
      cadenceTimer = 0;
      
      MarkovNode current = nodes.get(currentState);
      currentWord = current.token;
      current.flashIntensity = 1.0;
      
      generatedSpeech += currentWord + " ";
      if (generatedSpeech.length() > 220) {
        generatedSpeech = "> ..." + generatedSpeech.substring(generatedSpeech.length() - 180);
      }
      
      // Closed-Loop: Inject powerful depolarizing wave into the bound neuron!
      if (current.boundNeuronId >= 0 && current.boundNeuronId < lattice.size()) {
        Neuron n = lattice.get(current.boundNeuronId);
        n.injectCurrent(28.0); // Forces immediate action potential
      }
      
      // Advance Markov random walk biased by neural excitation
      currentState = current.selectNext(lattice);
    }
  }
  
  void render3DLabels(ArrayList<Neuron> lattice) {
    // Draw glowing word labels floating over bound active neurons in the 3D volume
    for (MarkovNode mn : nodes) {
      if (mn.flashIntensity > 0.05 && mn.boundNeuronId < lattice.size()) {
        Neuron n = lattice.get(mn.boundNeuronId);
        float alpha = mn.flashIntensity * 255.0;
        
        fill(255, 230, 80, alpha);
        stroke(255, 200, 50, alpha * 0.6);
        line(n.screenPos.x, n.screenPos.y, n.screenPos.x + 12, n.screenPos.y - 14);
        noStroke();
        text(mn.token, n.screenPos.x + 14, n.screenPos.y - 12);
      }
    }
  }
  
  void renderHUD(float x, float y, float w, float h) {
    fill(4, 6, 8, 230);
    stroke(25, 40, 50);
    rect(x, y, w, h);
    
    fill(240, 205, 50);
    text("ONE-BUTTON PRESIDENTIAL SPEECH [NEURAL-DRIVEN LLM PRECURSOR]", x + 12, y + 16);
    
    fill(60, 220, 150);
    ellipse(x + w - 16, y + 12, 6, 6);
    fill(120, 160, 180);
    text(String.format("TEMPO: %d FPS/WORD (COUPLED TO CORTICAL RHYTHM)", currentCadence), x + w - 280, y + 16);
    
    // Streamed speech text
    fill(210, 235, 250);
    text(generatedSpeech, x + 12, y + 36, w - 24, h - 42);
  }
}
