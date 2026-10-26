// =============================================================================
// FlyBrain.pde - Neuromorphic Diptera Micro-Brain, Learning Curve & Pixel HUD
// =============================================================================
// Biological Neuroarchitecture of Musca / Drosophila:
// 1. Sensory Influx (12 inputs):
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
    "VISION L", "VISION R", "GF LOOM", 
    "CARB ODOR", "PROT ODOR", "PHEROMONE",
    "FOOT SUGAR", "HALTERE", "SUN COMPASS",
    "HUNGER", "EGG URGE", "THIRST"
  };

  // 6 Internal Motivational States (Leaky Integrators)
  final int NUM_HIDDEN = 6;
  float[] hidden = new float[NUM_HIDDEN];
  float[] prevHidden = new float[NUM_HIDDEN];
  String[] hiddenLabels = {
    "FORAGE CARB", "FEED PROTEIN", "PHOTOTAXIS", "GF ESCAPE", "COURTSHIP", "GROOM/REST"
  };
  color[] hiddenColors = {
    color(255, 205, 50),  // Carb Forage (Amber Gold)
    color(235, 75, 140),  // Protein Feeding (Magenta)
    color(255, 240, 90),  // Phototaxis (Sun Yellow)
    color(255, 45, 45),   // Giant Fiber Escape (Alarm Red)
    color(140, 110, 255), // Courtship/Oviposition (Purple)
    color(70, 210, 240)   // Grooming/Rest (Cyan)
  };

  // 7 Motor Outputs
  final int NUM_OUTPUTS = 7;
  float[] outputs = new float[NUM_OUTPUTS];
  String[] outputLabels = {
    "WING POWER", "STEER YAW", "PITCH/ALT", 
    "JUMP (TTM)", "TRIPOD CPG", "PROBOSCIS", "OVIPOSIT"
  };

  // Synaptic Weights & Eligibility Traces (Dopamine Learning)
  float[][] wInputHidden = new float[NUM_INPUTS][NUM_HIDDEN];
  float[][] wHiddenHidden = new float[NUM_HIDDEN][NUM_HIDDEN];
  float[][] wHiddenOutput = new float[NUM_HIDDEN][NUM_OUTPUTS];
  float[][] eligibilityTraces = new float[NUM_INPUTS][NUM_HIDDEN];

  // Learning parameters (Mushroom Body Plasticity)
  float learningRate = 0.055;
  float dopamineReward = 0.0;
  float baselineReward = 0.0;
  float cumulativeReward = 0.0;
  float totalDeltaW = 0.0;
  int foodFoundCount = 0;

  // Real-time Learning Curve Oscilloscope Buffer (50 historical points)
  float[] rewardHistory = new float[50];
  int historyIndex = 0;

  // Leaky integrator dynamics
  float tau = 0.28;

  // Live Cognitive Thought
  String currentThought = "EXPLORING CUBE";
  color thoughtColor = color(180, 200, 240);
  int dominantMotivation = 0;

  // Animated Action Potentials (Spikes) along anatomical nerves
  ArrayList<ActionPotential> spikes = new ArrayList<ActionPotential>();

  FlyBrain() {
    initInnateWiring();
    for (int i = 0; i < rewardHistory.length; i++) rewardHistory[i] = 0;
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
    wHiddenHidden[3][0] = -3.0;
    wHiddenHidden[3][1] = -3.0;
    wHiddenHidden[3][4] = -3.0;
    wHiddenHidden[3][5] = -3.0;

    // 5. Pheromone + Protein Urge -> Courtship / Oviposition
    wInputHidden[5][4] = 2.6;
    wInputHidden[10][4] = 1.8;

    // 6. Fatigue / Cleanliness Need -> Grooming & Resting
    wInputHidden[9][5] = -1.2;
    wInputHidden[11][5] = 0.5;

    // Behavioral Persistence (Hidden recurrent self-excitations)
    for (int i = 0; i < NUM_HIDDEN; i++) {
      wHiddenHidden[i][i] = 0.42;
    }

    // Hidden -> Motor mapping
    wHiddenOutput[0][4] = 0.9;
    wHiddenOutput[0][5] = 2.2; // PER

    wHiddenOutput[1][4] = 0.9;
    wHiddenOutput[1][5] = 2.2;

    wHiddenOutput[2][0] = 1.4;
    wHiddenOutput[2][2] = 1.3;

    wHiddenOutput[3][0] = 2.8; // Max wing flap
    wHiddenOutput[3][3] = 3.5; // Catapult jump!

    wHiddenOutput[4][6] = 2.4;
    wHiddenOutput[4][4] = 0.6;

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
    cumulativeReward += max(0, reward);

    float rewardPredictionError = dopamineReward - baselineReward;
    baselineReward = lerp(baselineReward, dopamineReward, 0.07);

    // Update synapses based on eligibility traces
    float deltaSum = 0;
    for (int i = 0; i < NUM_INPUTS; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        float dw = learningRate * rewardPredictionError * eligibilityTraces[i][j];
        wInputHidden[i][j] += dw;
        wInputHidden[i][j] = constrain(wInputHidden[i][j], -4.0, 4.0);
        deltaSum += abs(dw);
      }
    }
    totalDeltaW += deltaSum;

    rewardHistory[historyIndex] = constrain(dopamineReward, -0.5, 2.0);
    historyIndex = (historyIndex + 1) % rewardHistory.length;
  }

  // Main neural computation cycle
  void compute(float visL, float visR, float loom, float carbOdor, float proteinOdor, 
               float pheromone, float tarsalSugar, float haltereGyro, float compass, 
               float trehaloseHunger, float proteinUrge, float thirst) {
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

    dopamineReward *= 0.88;

    float maxMot = -999;
    dominantMotivation = 0;

    for (int j = 0; j < NUM_HIDDEN; j++) {
      float sum = 0;
      for (int i = 0; i < NUM_INPUTS; i++) {
        sum += inputs[i] * wInputHidden[i][j];
        eligibilityTraces[i][j] = lerp(eligibilityTraces[i][j], inputs[i] * max(0, hidden[j]), 0.18);
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

    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float sum = 0;
      for (int j = 0; j < NUM_HIDDEN; j++) {
        sum += max(0, hidden[j]) * wHiddenOutput[j][k];
      }

      if (k == 1) { // Steering Yaw
        sum += (inputs[1] - inputs[0]) * 1.5;
        sum += inputs[8] * 1.2;
        sum += inputs[7] * 2.0;
        if (inputs[2] > 0.25) {
          sum += (inputs[0] > inputs[1] ? -2.5 : 2.5);
        }
      }

      outputs[k] = 1.0 / (1.0 + exp(-sum));
    }

    // Spawn animated action potentials along anatomical tracts
    if (frameCount % 3 == 0) {
      if (inputs[2] > 0.3) {
        spikes.add(new ActionPotential(0, 3, color(255, 60, 60), 2.4));
      } else if (dominantMotivation == 0 || dominantMotivation == 1) {
        spikes.add(new ActionPotential(1, 4, color(255, 210, 60), 1.6));
      } else if (dominantMotivation == 2) {
        spikes.add(new ActionPotential(2, 5, color(100, 220, 255), 1.7));
      }
    }

    for (int i = spikes.size() - 1; i >= 0; i--) {
      ActionPotential sp = spikes.get(i);
      sp.progress += 0.055 * sp.speed;
      if (sp.progress >= 1.0) spikes.remove(i);
    }

    if (frameCount % 10 == 0) {
      rewardHistory[historyIndex] = constrain(dopamineReward, -0.5, 2.0);
      historyIndex = (historyIndex + 1) % rewardHistory.length;
    }

    updateCognitiveThought();
  }

  void updateCognitiveThought() {
    thoughtColor = hiddenColors[dominantMotivation];
    switch(dominantMotivation) {
      case 0:
        currentThought = "FORAGING SUCROSE (TREHALOSE)";
        break;
      case 1:
        currentThought = "FEEDING PROTEIN (OOGENESIS)";
        break;
      case 2:
        currentThought = "PHOTOTAXIS / COMPASS CLIMB";
        break;
      case 3:
        currentThought = "!! GIANT FIBER ESCAPE !!";
        break;
      case 4:
        currentThought = "MATING WING SONG / OVIPOSIT";
        break;
      case 5:
      default:
        currentThought = "GROOMING HYGIENE & REST";
        break;
    }
  }

  // Nerve tract spatial interpolation for animated action potential spikes
  PVector getSpikePosition(int tract, float p) {
    if (tract == 0) {
      // Giant Fiber tract: Eyes -> Lobula -> Giant Fiber -> Thoracic TTM jump motor
      return new PVector(0, lerp(-74, -18, p));
    } else if (tract == 1) {
      // Feeding / Gustatory: Antennae/Feet -> Subesophageal Zone -> Proboscis
      return new PVector(lerp(-14, 0, p), lerp(-96, -60, p));
    } else {
      // Flight Motor: Optic Lobes -> CX -> Thoracic ganglion -> Flight Muscles / Halteres
      return new PVector(lerp(0, 26, p), lerp(-18, -26, p));
    }
  }

  // ---------------------------------------------------------------------------
  // Right Panel: Neuromorphic Brain & Pixel Oscilloscope
  // ---------------------------------------------------------------------------
  void displayLearningHUD(float px, float py, float pw, float ph) {
    pushStyle();
    // Pixel-Art Panel Container: 1-pixel border, sharp corners
    fill(10, 16, 26);
    stroke(55, 95, 140);
    strokeWeight(1);
    rect(px, py, pw, ph);

    // Pixel Title Banner
    fill(180, 225, 255);
    textAlign(LEFT, TOP);
    text("MUSHROOM BODY LEARNING", px + 8, py + 8);

    if (dopamineReward > 0.05) {
      fill(255, 215, 50);
      noStroke();
      rect(px + pw - 90, py + 7, 82, 12);
      fill(10, 16, 26);
      textAlign(CENTER, CENTER);
      text("+DOPAMINE", px + pw - 49, py + 12);
    }

    // Telemetry text
    fill(130, 180, 225);
    textAlign(LEFT, TOP);
    text("HITS:" + foodFoundCount + "  REW:" + nf(cumulativeReward, 0, 1) + "  DW:" + nf(totalDeltaW, 0, 2), px + 8, py + 22);

    // Pixel Oscilloscope
    float oscX = px + 8;
    float oscY = py + 36;
    float oscW = pw - 16;
    float oscH = 46;

    fill(6, 10, 16);
    stroke(40, 70, 105);
    rect(oscX, oscY, oscW, oscH);

    // Zero-line
    stroke(30, 55, 80);
    line(oscX, oscY + oscH * 0.72, oscX + oscW, oscY + oscH * 0.72);

    // Stepped pixel curve
    stroke(255, 205, 50);
    strokeWeight(1);
    noFill();
    for (int i = 0; i < rewardHistory.length - 1; i++) {
      int idx1 = (historyIndex + i) % rewardHistory.length;
      int idx2 = (historyIndex + i + 1) % rewardHistory.length;
      float gx1 = map(i, 0, rewardHistory.length - 1, oscX + 2, oscX + oscW - 2);
      float gx2 = map(i + 1, 0, rewardHistory.length - 1, oscX + 2, oscX + oscW - 2);
      float gy1 = map(rewardHistory[idx1], 0, 1.5, oscY + oscH * 0.72, oscY + 4);
      float gy2 = map(rewardHistory[idx2], 0, 1.5, oscY + oscH * 0.72, oscY + 4);
      line(gx1, gy1, gx2, gy2);
    }

    fill(160, 195, 230);
    textAlign(LEFT, TOP);
    text("DOPAMINE REWARD OSCILLOSCOPE", oscX + 4, oscY + 3);

    // Pixel Neural Synaptic Grid
    float netStartY = py + 92;
    float netH = ph - 100;
    float colInX = px + 10;
    float colMidX = px + pw * 0.44;
    float colOutX = px + pw - 12;

    // Draw active pixel connections
    strokeWeight(1);
    for (int i = 0; i < NUM_INPUTS; i++) {
      float y1 = map(i, 0, NUM_INPUTS - 1, netStartY, netStartY + netH);
      if (inputs[i] > 0.1) {
        for (int j = 0; j < NUM_HIDDEN; j++) {
          float y2 = map(j, 0, NUM_HIDDEN - 1, netStartY + 4, netStartY + netH - 4);
          float w = wInputHidden[i][j];
          if (abs(w) > 0.4) {
            stroke(w > 0 ? color(70, 210, 110, 140) : color(240, 70, 70, 140));
            line(colInX + 4, y1, colMidX - 4, y2);
          }
        }
      }
    }

    for (int j = 0; j < NUM_HIDDEN; j++) {
      float y2 = map(j, 0, NUM_HIDDEN - 1, netStartY + 4, netStartY + netH - 4);
      float act = max(0, hidden[j]);
      if (act > 0.1) {
        for (int k = 0; k < NUM_OUTPUTS; k++) {
          float y3 = map(k, 0, NUM_OUTPUTS - 1, netStartY, netStartY + netH);
          float w = wHiddenOutput[j][k];
          if (abs(w) > 0.35) {
            stroke(w > 0 ? color(90, 230, 140, 160) : color(240, 90, 90, 160));
            line(colMidX + 4, y2, colOutX - 4, y3);
          }
        }
      }
    }

    // Input Nodes (Chunky pixel squares)
    noStroke();
    for (int i = 0; i < NUM_INPUTS; i++) {
      float y = map(i, 0, NUM_INPUTS - 1, netStartY, netStartY + netH);
      float val = constrain(inputs[i], 0, 1);
      fill(lerpColor(color(30, 45, 60), color(90, 210, 255), val));
      rect(colInX - 2, y - 2, 5, 5);
    }

    // Hidden Motivation Nodes (Square pixel badges)
    for (int j = 0; j < NUM_HIDDEN; j++) {
      float y = map(j, 0, NUM_HIDDEN - 1, netStartY + 4, netStartY + netH - 4);
      float act = max(0, hidden[j]);
      fill(lerpColor(color(20, 30, 42), hiddenColors[j], act));
      stroke(hiddenColors[j]);
      strokeWeight(j == dominantMotivation ? 1.5 : 1.0);
      rect(colMidX - 4, y - 4, 8, 8);
      
      fill(160, 190, 220);
      textAlign(LEFT, CENTER);
      text(hiddenLabels[j], colMidX + 8, y);
    }

    // Motor Output Nodes (Square pixel boxes)
    noStroke();
    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float y = map(k, 0, NUM_OUTPUTS - 1, netStartY, netStartY + netH);
      float val = constrain(outputs[k], 0, 1);
      fill(lerpColor(color(30, 45, 60), color(120, 245, 160), val));
      rect(colOutX - 2, y - 2, 5, 5);
    }

    popStyle();
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
