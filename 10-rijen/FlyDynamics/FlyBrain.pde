// =============================================================================
// FlyBrain.pde - Neuromorphic Diptera Micro-Brain & Anatomical Reasoning HUD
// =============================================================================
// Biological Neuroarchitecture of Musca / Drosophila:
// 1. Sensory Influx:
//    - Compound Eyes (Ommatidia L/R) & Dorsal Ocelli
//    - Antennal Lobes: Carbohydrate Odor, Protein Odor, Sex Pheromone
//    - Gustatory Receptors on Tarsi ("Tasting with feet")
//    - Haltere Coriolis Gyroscopic Feedback (Angular roll/yaw/pitch stabilization)
//    - Internal Interoception: Trehalose fuel level, Protein load, Hydration, Cleanliness
// 2. Central Processing:
//    - Central Complex (CX): Compass heading ring attractor
//    - Mushroom Bodies (MB): Associative learning with Dopaminergic Neurons (DANs)
//    - Giant Fiber System (GF): Looming shadow escape jump reflex
// 3. Thoracic-Abdominal Ganglion (TAG):
//    - Central Pattern Generators (CPGs) for hexapod alternating tripod gait
//    - Asynchronous flight muscle motor neurons & haltere phase locking
// =============================================================================

class FlyBrain {
  // 12 Sensory Inputs
  final int NUM_INPUTS = 12;
  float[] inputs = new float[NUM_INPUTS];
  String[] inputLabels = {
    "Vision Lum L", "Vision Lum R", "Giant Fiber Loom", 
    "Carb Odor (Sugar)", "Protein Odor (Yeast)", "Pheromone",
    "Tarsal Sugar Taste", "Haltere Gyro", "Sun/Light Compass",
    "Trehalose Hunger", "Protein Urge", "Hydration Thirst"
  };

  // 6 Internal Motivational States (Leaky Integrators)
  final int NUM_HIDDEN = 6;
  float[] hidden = new float[NUM_HIDDEN];
  float[] prevHidden = new float[NUM_HIDDEN];
  String[] hiddenLabels = {
    "CARB FORAGING", "PROTEIN FEEDING", "PHOTOTAXIS", "GIANT FIBER ESCAPE", "COURTSHIP/OVIPOSIT", "GROOMING/REST"
  };
  color[] hiddenColors = {
    color(255, 215, 60),  // Carb Forage (Amber Gold)
    color(230, 80, 160),  // Protein Feeding (Magenta)
    color(255, 245, 110), // Phototaxis (Sun Yellow)
    color(255, 50, 50),   // Giant Fiber Escape (Alarm Red)
    color(130, 100, 255), // Courtship/Oviposition (Purple)
    color(80, 205, 240)   // Grooming/Rest (Cyan)
  };

  // 7 Motor Outputs
  final int NUM_OUTPUTS = 7;
  float[] outputs = new float[NUM_OUTPUTS];
  String[] outputLabels = {
    "Wing Power (DLM/DVM)", "Steering Yaw", "Pitch/Altitude", 
    "Takeoff Jump (TTM)", "Tripod Gait CPG", "Proboscis Ext (PER)", "Ovipositor/Wing Sing"
  };

  // Synaptic Weights & Eligibility Traces (Dopamine Learning)
  float[][] wInputHidden = new float[NUM_INPUTS][NUM_HIDDEN];
  float[][] wHiddenHidden = new float[NUM_HIDDEN][NUM_HIDDEN];
  float[][] wHiddenOutput = new float[NUM_HIDDEN][NUM_OUTPUTS];
  float[][] eligibilityTraces = new float[NUM_INPUTS][NUM_HIDDEN];

  // Learning parameters (Mushroom Body Plasticity)
  float learningRate = 0.04;
  float dopamineReward = 0.0;
  float baselineReward = 0.0;

  // Leaky integrator dynamics
  float tau = 0.28;

  // Live Cognitive Thought
  String currentThought = "EXPLORING ARENA";
  color thoughtColor = color(180, 200, 240);
  int dominantMotivation = 0;

  // Animated Action Potentials (Spikes) along anatomical nerves
  ArrayList<ActionPotential> spikes = new ArrayList<ActionPotential>();

  FlyBrain() {
    initInnateWiring();
  }

  void initInnateWiring() {
    // Innate behavioral reflexes hardwired into insect neurocircuitry:
    // 1. Carb Odor + Tarsal Sugar -> Carb Foraging
    wInputHidden[3][0] = 2.2; // Carb odor
    wInputHidden[6][0] = 2.8; // Tarsal sugar taste -> feeding!
    wInputHidden[9][0] = 1.8; // Trehalose hunger drive

    // 2. Protein Odor -> Protein Feeding
    wInputHidden[4][1] = 2.4;
    wInputHidden[10][1] = 2.5; // Protein urge for egg maturation

    // 3. Sun/Light Compass -> Phototaxis
    wInputHidden[0][2] = 0.6;
    wInputHidden[1][2] = 0.6;
    wInputHidden[8][2] = 2.0;

    // 4. Giant Fiber Looming Shadow -> Explosive Escape Reflex!
    wInputHidden[2][3] = 4.2; // Looming triggers GF
    // Giant Fiber strongly suppresses feeding, grooming, and courtship
    wHiddenHidden[3][0] = -3.0;
    wHiddenHidden[3][1] = -3.0;
    wHiddenHidden[3][4] = -3.0;
    wHiddenHidden[3][5] = -3.0;

    // 5. Pheromone + Protein Urge -> Courtship / Oviposition
    wInputHidden[5][4] = 2.6;
    wInputHidden[10][4] = 1.8;

    // 6. Fatigue / Cleanliness Need -> Grooming & Resting
    wInputHidden[9][5] = -1.2; // High hunger suppresses grooming
    wInputHidden[11][5] = 0.5;

    // Behavioral Persistence (Hidden recurrent self-excitations)
    for (int i = 0; i < NUM_HIDDEN; i++) {
      wHiddenHidden[i][i] = 0.42;
    }

    // Hidden -> Motor mapping
    // Carb Forage -> Tripod crawl, Proboscis extension reflex (PER)
    wHiddenOutput[0][4] = 0.9;
    wHiddenOutput[0][5] = 2.2; // PER

    // Protein Feed -> Crawl, PER
    wHiddenOutput[1][4] = 0.9;
    wHiddenOutput[1][5] = 2.2;

    // Phototaxis -> High wing thrust, climb
    wHiddenOutput[2][0] = 1.4;
    wHiddenOutput[2][2] = 1.3;

    // Giant Fiber Escape -> Catapult Jump (TTM muscle), Max Wing Power
    wHiddenOutput[3][0] = 2.8; // Max wing flap
    wHiddenOutput[3][3] = 3.5; // Catapult jump!

    // Courtship / Oviposition -> Wing song / Ovipositor deposit
    wHiddenOutput[4][6] = 2.4;
    wHiddenOutput[4][4] = 0.6;

    // Grooming -> Stop wings, leg wiping
    wHiddenOutput[5][0] = -2.0;
    wHiddenOutput[5][4] = 0.5;
  }

  // Clone with slight synaptic mutations for offspring generations
  FlyBrain mutateCopy() {
    FlyBrain child = new FlyBrain();
    for (int i = 0; i < NUM_INPUTS; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        child.wInputHidden[i][j] = this.wInputHidden[i][j] + random(-0.06, 0.06);
      }
    }
    for (int i = 0; i < NUM_HIDDEN; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        child.wHiddenHidden[i][j] = this.wHiddenHidden[i][j] + random(-0.05, 0.05);
      }
      for (int k = 0; k < NUM_OUTPUTS; k++) {
        child.wHiddenOutput[i][k] = this.wHiddenOutput[i][k] + random(-0.06, 0.06);
      }
    }
    return child;
  }

  // Dopaminergic associative learning update (Mushroom Body Plasticity)
  void applyDopamineReward(float reward) {
    dopamineReward = reward;
    float rewardPredictionError = dopamineReward - baselineReward;
    baselineReward = lerp(baselineReward, dopamineReward, 0.08);

    // Update synapses based on eligibility traces
    for (int i = 0; i < NUM_INPUTS; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        wInputHidden[i][j] += learningRate * rewardPredictionError * eligibilityTraces[i][j];
        wInputHidden[i][j] = constrain(wInputHidden[i][j], -4.0, 4.0);
      }
    }
  }

  // Main neural computation cycle
  void compute(float visL, float visR, float loom, float carbOdor, float proteinOdor, 
               float pheromone, float tarsalSugar, float haltereGyro, float compass, 
               float trehaloseHunger, float proteinUrge, float thirst) {
    // 1. Pack inputs
    inputs[0] = visL;
    inputs[1] = visR;
    inputs[2] = loom;
    inputs[3] = carbOdor;
    inputs[4] = proteinOdor;
    inputs[5] = pheromone;
    inputs[6] = tarsalSugar;
    inputs[7] = haltereGyro;
    inputs[8] = compass;
    inputs[9] = trehaloseHunger;
    inputs[10] = proteinUrge;
    inputs[11] = thirst;

    // Decay dopamine reward display
    dopamineReward *= 0.88;

    // 2. Hidden Layer (Recurrent Leaky Integrators)
    float maxMot = -999;
    dominantMotivation = 0;

    for (int j = 0; j < NUM_HIDDEN; j++) {
      float sum = 0;
      for (int i = 0; i < NUM_INPUTS; i++) {
        sum += inputs[i] * wInputHidden[i][j];
        // Update eligibility trace
        eligibilityTraces[i][j] = lerp(eligibilityTraces[i][j], inputs[i] * max(0, hidden[j]), 0.15);
      }
      for (int k = 0; k < NUM_HIDDEN; k++) {
        sum += prevHidden[k] * wHiddenHidden[k][j];
      }

      float target = (float)Math.tanh(sum);
      hidden[j] = lerp(prevHidden[j], target, tau);
      prevHidden[j] = hidden[j];

      if (hidden[j] > maxMot) {
        maxMot = hidden[j];
        dominantMotivation = j;
      }
    }

    // 3. Motor Outputs
    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float sum = 0;
      for (int j = 0; j < NUM_HIDDEN; j++) {
        sum += max(0, hidden[j]) * wHiddenOutput[j][k];
      }

      // Haltere reflex direct stabilization:
      // When haltere detects roll/yaw instability, it directly activates steering muscles
      if (k == 1) { // Steering Yaw
        sum += (inputs[1] - inputs[0]) * 1.5; // Phototaxis differential
        sum += inputs[8] * 1.2;               // Sun compass orientation
        sum += inputs[7] * 2.0;               // Haltere gyro correction
        if (inputs[2] > 0.25) {
          sum += (inputs[0] > inputs[1] ? -2.5 : 2.5); // Giant Fiber flee away
        }
      }

      // Sigmoid output activation
      outputs[k] = 1.0 / (1.0 + exp(-sum));
    }

    // Spawn animated action potentials along anatomical tracts
    if (frameCount % 4 == 0) {
      if (inputs[2] > 0.3) {
        // Giant Fiber spike
        spikes.add(new ActionPotential(0, 3, color(255, 60, 60), 2.2));
      } else if (dominantMotivation == 0 || dominantMotivation == 1) {
        // Antennal / Gustatory feeding spike
        spikes.add(new ActionPotential(1, 4, color(255, 210, 60), 1.5));
      } else if (dominantMotivation == 2) {
        // Optic / Flight spike
        spikes.add(new ActionPotential(2, 5, color(100, 220, 255), 1.6));
      }
    }

    // Update spikes
    for (int i = spikes.size() - 1; i >= 0; i--) {
      ActionPotential sp = spikes.get(i);
      sp.progress += 0.05 * sp.speed;
      if (sp.progress >= 1.0) spikes.remove(i);
    }

    updateCognitiveThought();
  }

  void updateCognitiveThought() {
    thoughtColor = hiddenColors[dominantMotivation];
    switch(dominantMotivation) {
      case 0:
        currentThought = "FORAGING SUCROSE (FLIGHT FUEL)";
        break;
      case 1:
        currentThought = "FEEDING PROTEIN (VITELLOGENESIS)";
        break;
      case 2:
        currentThought = "PHOTOTAXIS & SUN COMPASS NAV";
        break;
      case 3:
        currentThought = "!! GIANT FIBER ESCAPE JUMP !!";
        break;
      case 4:
        currentThought = "MATING COURTSHIP / OVIPOSITION";
        break;
      case 5:
      default:
        currentThought = "GROOMING SENSORS & RESTING";
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Anatomical Neuro-Reasoning Laboratory HUD
  // ---------------------------------------------------------------------------
  void displayHUD(float px, float py, float pw, float ph) {
    pushStyle();
    // Glass HUD Panel
    fill(10, 16, 26, 235);
    stroke(70, 130, 200, 160);
    strokeWeight(1.5);
    rect(px, py, pw, ph, 8);

    // Title & Live Thought Badge
    fill(180, 225, 255);
    textAlign(LEFT, TOP);
    textSize(11);
    text("DIPTERA NEUROANATOMY & COGNITIVE REASONING", px + 12, py + 8);

    // Dopamine reward flash
    if (dopamineReward > 0.05) {
      fill(255, 220, 40, dopamineReward * 200);
      noStroke();
      rect(px + pw - 340, py + 7, 75, 18, 4);
      fill(0);
      textAlign(CENTER, CENTER);
      textSize(9);
      text("+DOPAMINE", px + pw - 302, py + 16);
    }

    // Live thought badge
    fill(thoughtColor, 40);
    stroke(thoughtColor, 180);
    strokeWeight(1);
    rect(px + pw - 250, py + 7, 238, 19, 4);
    fill(thoughtColor);
    textAlign(CENTER, CENTER);
    textSize(9);
    text(currentThought, px + pw - 131, py + 16);

    // Left Column: Sensory Influx Meters
    float colSensX = px + 12;
    float startY = py + 34;
    float rowH = (ph - 42) / NUM_INPUTS;

    textAlign(LEFT, CENTER);
    textSize(8.5);
    for (int i = 0; i < NUM_INPUTS; i++) {
      float y = startY + i * rowH;
      fill(160, 190, 220);
      text(inputLabels[i], colSensX, y);

      // Meter bar
      float val = constrain(inputs[i], 0, 1);
      noStroke();
      fill(25, 38, 52);
      rect(colSensX + 96, y - 3, 50, 6, 2);
      fill(lerpColor(color(70, 140, 220), color(255, 190, 60), val));
      rect(colSensX + 96, y - 3, 50 * val, 6, 2);
    }

    // Center Viewport: Actual Anatomical Fly Diagram with Neural Tracts!
    float diagCenterX = px + pw * 0.49;
    float diagCenterY = py + ph * 0.53;
    drawAnatomicalDiagram(diagCenterX, diagCenterY, 0.72);

    // Right Column: Motor Actuators & CPG
    float colActX = px + pw - 150;
    textAlign(LEFT, CENTER);
    textSize(8.5);
    float actRowH = (ph - 42) / NUM_OUTPUTS;

    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float y = startY + k * actRowH + 6;
      fill(160, 190, 220);
      text(outputLabels[k], colActX, y);

      float val = constrain(outputs[k], 0, 1);
      noStroke();
      fill(25, 38, 52);
      rect(colActX + 92, y - 3, 45, 6, 2);
      fill(lerpColor(color(60, 180, 120), color(255, 80, 80), val));
      rect(colActX + 92, y - 3, 45 * val, 6, 2);
    }

    popStyle();
  }

  // Draw authentic dorsal anatomical schematic of Musca domestica
  void drawAnatomicalDiagram(float cx, float cy, float scale) {
    pushMatrix();
    translate(cx, cy);
    scale(scale);

    // 1. Semi-translucent body cutaway silhouette
    noStroke();
    fill(20, 32, 48, 140);
    // Head capsule
    ellipse(0, -65, 42, 32);
    // Thorax
    ellipse(0, -18, 48, 56);
    // Abdomen
    ellipse(0, 48, 42, 70);

    // Compound Eyes (Left & Right)
    fill(180, 30, 25, 200);
    stroke(220, 50, 40);
    strokeWeight(1);
    ellipse(-15, -67, 14, 22);
    ellipse(15, -67, 14, 22);

    // 3 Ocelli on vertex
    fill(255, 240, 120);
    noStroke();
    ellipse(0, -74, 3, 3);
    ellipse(-4, -71, 2.5, 2.5);
    ellipse(4, -71, 2.5, 2.5);

    // Antennae with arista
    stroke(180, 200, 220);
    strokeWeight(1.2);
    line(-6, -78, -12, -90);
    line(6, -78, 12, -90);
    line(-12, -90, -17, -94);
    line(12, -90, 17, -94);

    // 2. Central Nervous System Schematics:
    // A. Optic Lobes (Lamina, Medulla, Lobula)
    noFill();
    stroke(80, 200, 255, 180);
    strokeWeight(1.2);
    ellipse(-9, -65, 8, 14);
    ellipse(9, -65, 8, 14);

    // B. Central Complex (CX) - Ring Attractor & Protocerebral Bridge
    fill(255, 210, 80, 180);
    stroke(255, 230, 100);
    strokeWeight(1);
    ellipse(0, -62, 10, 7);

    // C. Mushroom Bodies (Learning & Olfaction)
    fill(220, 90, 180, 180);
    noStroke();
    ellipse(-6, -58, 5, 5);
    ellipse(6, -58, 5, 5);

    // D. Neck Connective (Ventral Nerve Cord descent)
    stroke(120, 220, 255);
    strokeWeight(2);
    line(0, -50, 0, -32);

    // E. Thoracic-Abdominal Ganglion (TAG)
    fill(60, 180, 230, 200);
    stroke(100, 220, 255);
    strokeWeight(1.2);
    ellipse(0, -18, 18, 28);

    // F. Halteres (Coriolis Gyro Organs)
    stroke(255, 180, 50);
    strokeWeight(1.5);
    line(-20, -5, -34, -2);
    line(20, -5, 34, -2);
    fill(255, 200, 80);
    ellipse(-34, -2, 5, 5);
    ellipse(34, -2, 5, 5);

    // G. Leg Motor Nerves radiating from Thoracic Ganglion to 6 Legs
    stroke(80, 190, 240, 160);
    strokeWeight(1.0);
    // Prothoracic Legs (Front L1/R1)
    line(0, -24, -28, -38);
    line(0, -24, 28, -38);
    // Mesothoracic Legs (Middle L2/R2)
    line(0, -18, -32, -18);
    line(0, -18, 32, -18);
    // Metathoracic Legs (Hind L3/R3)
    line(0, -12, -26, 6);
    line(0, -12, 26, 6);

    // H. Direct Flight Muscle Nerves (Wing hinges)
    stroke(255, 100, 100, 160);
    line(0, -22, -22, -26);
    line(0, -22, 22, -26);

    // I. Abdominal Ganglion tract (Ovipositor / Digestion)
    stroke(120, 220, 255, 140);
    line(0, -4, 0, 68);

    // 3. Render animated glowing Action Potentials along tracts
    for (ActionPotential ap : spikes) {
      PVector spPos = getSpikePosition(ap.tract, ap.progress);
      noStroke();
      fill(ap.col);
      ellipse(spPos.x, spPos.y, 4.5, 4.5);
      fill(255, 200);
      ellipse(spPos.x, spPos.y, 2, 2);
    }

    // Anatomical Labels
    fill(140, 180, 220);
    textAlign(CENTER, TOP);
    textSize(7.5);
    text("OPTIC LOBES", -20, -96);
    text("CENTRAL COMPLEX", 0, -52);
    text("THORACIC GANGLION", 0, 0);
    text("HALTERES", -38, -12);

    popMatrix();
  }

  PVector getSpikePosition(int tract, float p) {
    if (tract == 0) {
      // Giant Fiber tract: Eyes -> Lobula -> Giant Fiber -> Thoracic TTM jump motor
      return new PVector(0, lerp(-65, -18, p));
    } else if (tract == 1) {
      // Feeding / Gustatory: Antennae/Feet -> Subesophageal Zone -> Proboscis
      return new PVector(lerp(-12, 0, p), lerp(-85, -55, p));
    } else {
      // Flight Motor: Optic Lobes -> CX -> Thoracic ganglion -> Flight Muscles / Halteres
      return new PVector(lerp(0, 22, p), lerp(-18, -26, p));
    }
  }
}

// -----------------------------------------------------------------------------
// Action Potential Entity (Neural Spark traveling down nerve tract)
// -----------------------------------------------------------------------------
class ActionPotential {
  int fromNode;
  int tract;
  color col;
  float progress = 0;
  float speed = 1.0;

  ActionPotential(int from, int tract, color col, float spd) {
    this.fromNode = from;
    this.tract = tract;
    this.col = col;
    this.speed = spd;
  }
}
