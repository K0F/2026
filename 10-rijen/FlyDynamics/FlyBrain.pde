// =============================================================================
// FlyBrain.pde - Diptera Cognitive Model: Spatial Working Memory & Saccades
// =============================================================================
// Janelia Connectome Cognitive Model:
// 1. Central Complex (CX) Spatial Working Memory:
//    - Memorizes 3D coordinates of what the fly has seen:
//      * Sugar / Carbohydrate locations (fuel)
//      * Protein / Yeast substrate (vitellogenesis & eggs)
//      * Water dew condensation points (hydration)
//      * Warm ceiling perches (thermoregulation & sleep)
// 2. Goal Arbitration:
//    - Evaluates internal homeostatic deficits (trehalose, protein, hydration, temp)
//    - Selects deliberate behavioral target from spatial memory
// 3. Proportional Navigation & Smooth Flight Guidance:
//    - Inter-saccadic straight cruising vs locked target approach
// =============================================================================

// Distinct Model Behaviors
final int BEHAVIOR_CRUISE = 0;           // Steady straight cruising with occasional saccades
final int BEHAVIOR_TARGET_SUGAR = 1;     // Direct flight to remembered sugar coordinates
final int BEHAVIOR_TARGET_PROTEIN = 2;   // Direct flight to remembered protein coordinates
final int BEHAVIOR_TARGET_DEW = 3;       // Direct flight to remembered condensation dew
final int BEHAVIOR_TARGET_PERCH = 4;     // Flight to warm ceiling wire for restful torpor
final int BEHAVIOR_PRECISION_LAND = 5;   // Controlled deceleration & touchdown on food
final int BEHAVIOR_FEEDING = 6;          // Proboscis extension feeding
final int BEHAVIOR_GROOMING = 7;         // Systematic hygiene cleaning
final int BEHAVIOR_COURTSHIP = 8;        // Male pursuit and unilateral wing song
final int BEHAVIOR_ESCAPE = 9;           // Giant Fiber evasive catapult jump

class FlyBrain {
  final int NUM_INPUTS = 12;
  float[] inputs = new float[NUM_INPUTS];

  final int NUM_HIDDEN = 6;
  float[] hidden = new float[NUM_HIDDEN];
  float[] prevHidden = new float[NUM_HIDDEN];
  color[] hiddenColors = {
    color(255, 205, 50),  // Carb Forage
    color(235, 75, 140),  // Protein Feeding
    color(255, 240, 90),  // Phototaxis
    color(255, 45, 45),   // Giant Fiber Escape
    color(140, 110, 255), // Courtship
    color(70, 210, 240)   // Grooming/Rest
  };

  final int NUM_OUTPUTS = 7;
  float[] outputs = new float[NUM_OUTPUTS];

  // Synaptic Weights & Eligibility Traces
  float[][] wInputHidden = new float[NUM_INPUTS][NUM_HIDDEN];
  float[][] wHiddenHidden = new float[NUM_HIDDEN][NUM_HIDDEN];
  float[][] wHiddenOutput = new float[NUM_HIDDEN][NUM_OUTPUTS];
  float[][] eligibilityTraces = new float[NUM_INPUTS][NUM_HIDDEN];

  // Learning parameters
  float learningRate = 0.055;
  float dopamineReward = 0.0;
  float baselineReward = 0.0;
  float cumulativeReward = 0.0;
  float totalDeltaW = 0.0;
  int foodFoundCount = 0;

  // SPATIAL WORKING MEMORY: What the fly has seen and where to get it!
  PVector memSugarLoc = null;
  float memSugarConf = 0.0; // 0.0 to 1.0

  PVector memProteinLoc = null;
  float memProteinConf = 0.0;

  PVector memDewLoc = null;
  float memDewConf = 0.0;

  PVector memPerchLoc = new PVector(0, 0, 440);
  float memPerchConf = 0.8;

  // Active Navigation Target
  PVector activeTarget = null;
  String targetDescription = "NONE";

  // Central Complex Ring Attractor (Compass Heading)
  float[] ringAttractor = new float[8];
  float internalCompassAngle = 0.0;

  // Behavioral Model State & Thought Description
  int activeBehavior = BEHAVIOR_CRUISE;
  String currentThought = "STEADY ARENA CRUISE";
  color thoughtColor = color(150, 210, 255);

  float[] rewardHistory = new float[50];
  int historyIndex = 0;
  float tau = 0.28;

  ArrayList<ActionPotential> spikes = new ArrayList<ActionPotential>();

  FlyBrain() {
    initInnateWiring();
    for (int i = 0; i < rewardHistory.length; i++) rewardHistory[i] = 0;
    for (int i = 0; i < 8; i++) ringAttractor[i] = 0.1;
  }

  void initInnateWiring() {
    wInputHidden[3][0] = 2.4;
    wInputHidden[6][0] = 2.8;
    wInputHidden[9][0] = 2.2;

    wInputHidden[4][1] = 2.4;
    wInputHidden[10][1] = 2.6;

    wInputHidden[0][2] = 0.6;
    wInputHidden[1][2] = 0.6;
    wInputHidden[8][2] = 2.0;

    wInputHidden[2][3] = 4.2;
    wHiddenHidden[3][0] = -3.0;
    wHiddenHidden[3][1] = -3.0;
    wHiddenHidden[3][4] = -3.0;
    wHiddenHidden[3][5] = -3.0;

    wInputHidden[5][4] = 2.6;
    wInputHidden[10][4] = 1.8;

    wInputHidden[9][5] = -1.5;
    wInputHidden[11][5] = 0.6;

    for (int i = 0; i < NUM_HIDDEN; i++) {
      wHiddenHidden[i][i] = 0.42;
    }

    wHiddenOutput[0][0] = 1.2;
    wHiddenOutput[0][3] = 1.4;
    wHiddenOutput[0][4] = 0.9;
    wHiddenOutput[0][5] = 2.4;

    wHiddenOutput[1][0] = 1.2;
    wHiddenOutput[1][3] = 1.4;
    wHiddenOutput[1][4] = 0.9;
    wHiddenOutput[1][5] = 2.4;

    wHiddenOutput[2][0] = 1.5;
    wHiddenOutput[2][2] = 1.4;
    wHiddenOutput[2][3] = 1.5;

    wHiddenOutput[3][0] = 3.0;
    wHiddenOutput[3][3] = 4.0;

    wHiddenOutput[4][0] = 0.8;
    wHiddenOutput[4][3] = 1.0;
    wHiddenOutput[4][6] = 2.5;

    wHiddenOutput[5][0] = -2.0;
    wHiddenOutput[5][4] = 0.5;
  }

  FlyBrain mutateCopy() {
    FlyBrain child = new FlyBrain();
    for (int i = 0; i < NUM_INPUTS; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        child.wInputHidden[i][j] = this.wInputHidden[i][j] + random(-0.04, 0.04);
      }
    }
    for (int i = 0; i < NUM_HIDDEN; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        child.wHiddenHidden[i][j] = this.wHiddenHidden[i][j] + random(-0.03, 0.03);
      }
      for (int k = 0; k < NUM_OUTPUTS; k++) {
        child.wHiddenOutput[i][k] = this.wHiddenOutput[i][k] + random(-0.04, 0.04);
      }
    }
    return child;
  }

  // Visual & Tarsal Working Memory: Record what the fly sees and where to get it!
  void recordSeenFood(PVector loc, int foodType, float confidence) {
    if (foodType == 0) { // FOOD_CARB
      memSugarLoc = loc.copy();
      memSugarConf = confidence;
    } else { // FOOD_PROTEIN
      memProteinLoc = loc.copy();
      memProteinConf = confidence;
    }
  }

  void recordSeenPoi(PVector loc, int poiType, float confidence) {
    if (poiType == 0) { // POI_WATER
      memDewLoc = loc.copy();
      memDewConf = confidence;
    } else if (poiType == 1) { // POI_WARM
      memPerchLoc = loc.copy();
      memPerchConf = confidence;
    }
  }

  void applyDopamineReward(float reward) {
    dopamineReward = reward;
    cumulativeReward += max(0, reward);

    float rewardPredictionError = dopamineReward - baselineReward;
    baselineReward = lerp(baselineReward, dopamineReward, 0.07);

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

  // Cognitive Thinking & Deliberation Engine
  void computeThinking(float visL, float visR, float loom, float carbOdor, float proteinOdor, 
                       float pheromone, float tarsalSugar, float haltereGyro, float compass, 
                       float hunger, float eggUrge, float thirst, 
                       PVector flyPos, float flyHeading, float flyTemp, int flyState, boolean isFemale) {
    // 1. Influx
    inputs[0] = visL;
    inputs[1] = visR;
    inputs[2] = loom;
    inputs[3] = carbOdor;
    inputs[4] = proteinOdor;
    inputs[5] = pheromone;
    inputs[6] = tarsalSugar;
    inputs[7] = haltereGyro;
    inputs[8] = compass;
    inputs[9] = hunger;
    inputs[10] = eggUrge;
    inputs[11] = thirst;

    dopamineReward *= 0.88;

    // Memory Decay
    if (memSugarConf > 0) memSugarConf = max(0, memSugarConf - 0.00025);
    if (memProteinConf > 0) memProteinConf = max(0, memProteinConf - 0.00025);
    if (memDewConf > 0) memDewConf = max(0, memDewConf - 0.00025);

    // 2. Central Complex Ring Attractor
    internalCompassAngle = flyHeading;
    int activeWedge = int(map((flyHeading + TWO_PI) % TWO_PI, 0, TWO_PI, 0, 8)) % 8;
    for (int i = 0; i < 8; i++) {
      float target = (i == activeWedge) ? 1.0 : 0.05;
      ringAttractor[i] = lerp(ringAttractor[i], target, 0.2);
    }

    // 3. Hidden Layer Integrator
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
    }

    // 4. Model Behavior Selection from Homeostatic Needs & Spatial Memory
    deliberateModelBehavior(flyPos, flyHeading, flyTemp, flyState, isFemale);

    // 5. Motor Outputs
    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float sum = 0;
      for (int j = 0; j < NUM_HIDDEN; j++) {
        sum += max(0, hidden[j]) * wHiddenOutput[j][k];
      }

      // Drive motor commands according to active deliberate target
      if (hasActiveTarget()) {
        if (k == 0) sum += 1.4; // Strong forward cruise thrust
        if (k == 3) sum += 1.6; // Voluntary takeoff jump if landed
      }

      outputs[k] = 1.0 / (1.0 + exp(-sum));
    }

    // Sparks along nerves
    if (frameCount % 3 == 0) {
      if (inputs[2] > 0.3) {
        spikes.add(new ActionPotential(0, 3, color(255, 60, 60), 2.4));
      } else if (activeBehavior == BEHAVIOR_TARGET_SUGAR || activeBehavior == BEHAVIOR_FEEDING) {
        spikes.add(new ActionPotential(1, 4, color(255, 210, 60), 1.6));
      } else {
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
  }

  // Model Behavior Deliberation: Evaluates internal states & memory
  void deliberateModelBehavior(PVector flyPos, float flyHeading, float flyTemp, int flyState, boolean isFemale) {
    // 1. Giant Fiber Looming Shadow (Survival reflex overrides everything)
    if (inputs[2] > 0.32) {
      activeBehavior = BEHAVIOR_ESCAPE;
      activeTarget = null;
      targetDescription = "EVADE SHADOW";
      currentThought = "! GIANT FIBER EVASIVE ESCAPE !";
      thoughtColor = color(255, 45, 45);
      return;
    }

    // 2. Feeding on Food Contact
    if (flyState == 4 || inputs[6] > 0.5) { // STATE_FEEDING
      activeBehavior = BEHAVIOR_FEEDING;
      activeTarget = null;
      targetDescription = "FEEDING PROBOSCIS";
      currentThought = "PROBOSCIS SUCROSE INGESTION";
      thoughtColor = color(255, 205, 50);
      return;
    }

    // 3. Poikilothermy: Cold fly targets warm ceiling perch
    if (flyTemp < 21.0 && memPerchLoc != null) {
      activeBehavior = BEHAVIOR_TARGET_PERCH;
      activeTarget = memPerchLoc;
      targetDescription = "WARM PERCH";
      currentThought = "THERMAL BASKING: TARGETING WARM CEILING";
      thoughtColor = color(255, 180, 70);
      return;
    }

    // 4. Thirsty fly targets remembered condensation dew on glass
    if (inputs[11] > 0.45 && memDewLoc != null && memDewConf > 0.2) {
      activeBehavior = BEHAVIOR_TARGET_DEW;
      activeTarget = memDewLoc;
      targetDescription = "GLASS DEW (" + int(memDewConf * 100) + "%)";
      currentThought = "HYDRATION: FLYING STRAIGHT TO DEW";
      thoughtColor = color(70, 210, 240);
      return;
    }

    // 5. Female Gravid with Eggs targets remembered protein substrate
    if (isFemale && inputs[10] > 0.45 && memProteinLoc != null && memProteinConf > 0.2) {
      activeBehavior = BEHAVIOR_TARGET_PROTEIN;
      activeTarget = memProteinLoc;
      targetDescription = "YEAST SUBSTRATE (" + int(memProteinConf * 100) + "%)";
      currentThought = "OOGENESIS: DIRECT FLIGHT TO YEAST";
      thoughtColor = color(235, 75, 140);
      return;
    }

    // 6. Hungry fly targets remembered sugar location
    if (inputs[9] > 0.35 && memSugarLoc != null && memSugarConf > 0.2) {
      activeBehavior = BEHAVIOR_TARGET_SUGAR;
      activeTarget = memSugarLoc;
      targetDescription = "SUCROSE (" + int(memSugarConf * 100) + "%)";
      currentThought = "HUNGER: DIRECT FLIGHT TO REMEMBERED SUGAR";
      thoughtColor = color(255, 215, 60);
      return;
    }

    // 7. Male Courtship
    if (!isFemale && inputs[5] > 0.45) {
      activeBehavior = BEHAVIOR_COURTSHIP;
      targetDescription = "FEMALE PHEROMONE";
      currentThought = "COURTSHIP PURSUIT & 165 HZ WING SERENADE";
      thoughtColor = color(140, 110, 255);
      return;
    }

    // 8. Grooming when dusty
    if (flyState == 5) { // STATE_GROOMING
      activeBehavior = BEHAVIOR_GROOMING;
      activeTarget = null;
      targetDescription = "HYGIENE";
      currentThought = "GROOMING COMPOUND EYES & LEGS";
      thoughtColor = color(80, 230, 130);
      return;
    }

    // 9. Default Model: Steady, smooth inter-saccadic cruising
    activeBehavior = BEHAVIOR_CRUISE;
    activeTarget = null;
    targetDescription = "SURVEYING ARENA";
    currentThought = "STEADY CRUISE & COMPOUND RETINA SURVEY";
    thoughtColor = color(150, 210, 255);
  }

  boolean hasActiveTarget() {
    return (activeTarget != null);
  }

  PVector getActiveTarget() {
    return activeTarget;
  }

  PVector getSpikePosition(int tract, float p) {
    if (tract == 0) {
      return new PVector(0, lerp(-74, -18, p));
    } else if (tract == 1) {
      return new PVector(lerp(-14, 0, p), lerp(-96, -60, p));
    } else {
      return new PVector(lerp(0, 26, p), lerp(-18, -26, p));
    }
  }

  // ---------------------------------------------------------------------------
  // Right HUD Panel: Spatial Memory, Ring Attractor & Learning Oscilloscope
  // ---------------------------------------------------------------------------
  void displayLearningHUD(float px, float py, float pw, float ph) {
    pushStyle();
    fill(10, 16, 26);
    stroke(55, 95, 140);
    strokeWeight(1);
    rect(px, py, pw, ph);

    // Title
    fill(180, 225, 255);
    textAlign(LEFT, TOP);
    text("COGNITIVE MEMORY & CENTRAL COMPLEX", px + 8, py + 8);

    if (dopamineReward > 0.05) {
      fill(255, 215, 50);
      noStroke();
      rect(px + pw - 88, py + 7, 80, 12);
      fill(10, 16, 26);
      textAlign(CENTER, CENTER);
      text("+DOPAMINE", px + pw - 48, py + 12);
    }

    // Spatial Memory readout
    fill(130, 180, 225);
    textAlign(LEFT, TOP);
    text("TARGET: " + targetDescription + "  |  HITS: " + foodFoundCount + "  |  REW: " + nf(cumulativeReward, 0, 1), px + 8, py + 22);

    // Pixel Oscilloscope
    float oscX = px + 8;
    float oscY = py + 36;
    float oscW = pw - 85;
    float oscH = 46;

    fill(6, 10, 16);
    stroke(40, 70, 105);
    rect(oscX, oscY, oscW, oscH);

    stroke(30, 55, 80);
    line(oscX, oscY + oscH * 0.72, oscX + oscW, oscY + oscH * 0.72);

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
    text("REWARD OSCILLOSCOPE", oscX + 4, oscY + 3);

    // Central Complex Ring Attractor
    float ringX = px + pw - 42;
    float ringY = py + 59;

    fill(6, 10, 16);
    stroke(40, 70, 105);
    rect(ringX - 35, py + 36, 70, oscH);

    fill(160, 195, 230);
    textAlign(CENTER, TOP);
    text("RING CX", ringX, py + 38);

    for (int i = 0; i < 8; i++) {
      float a = map(i, 0, 8, 0, TWO_PI) - HALF_PI;
      float wx = ringX + cos(a) * 14;
      float wy = (ringY + 6) + sin(a) * 11;
      fill(lerpColor(color(20, 35, 50), color(90, 220, 255), ringAttractor[i]));
      noStroke();
      rect(wx - 2, wy - 2, 4, 4);
    }

    stroke(255, 205, 50);
    strokeWeight(1.5);
    line(ringX, ringY + 6, ringX + cos(internalCompassAngle - HALF_PI) * 12, (ringY + 6) + sin(internalCompassAngle - HALF_PI) * 10);

    // Active Synapses
    float netStartY = py + 92;
    float netH = ph - 100;
    float colInX = px + 10;
    float colMidX = px + pw * 0.44;
    float colOutX = px + pw - 12;

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

    noStroke();
    for (int i = 0; i < NUM_INPUTS; i++) {
      float y = map(i, 0, NUM_INPUTS - 1, netStartY, netStartY + netH);
      float val = constrain(inputs[i], 0, 1);
      fill(lerpColor(color(30, 45, 60), color(90, 210, 255), val));
      rect(colInX - 2, y - 2, 5, 5);
    }

    String[] hiddenTags = {"CARB", "PROT", "LIGHT", "ESCAPE", "MATE", "REST"};
    for (int j = 0; j < NUM_HIDDEN; j++) {
      float y = map(j, 0, NUM_HIDDEN - 1, netStartY + 4, netStartY + netH - 4);
      float act = max(0, hidden[j]);
      fill(lerpColor(color(20, 30, 42), hiddenColors[j], act));
      stroke(hiddenColors[j]);
      rect(colMidX - 4, y - 4, 8, 8);
      
      fill(160, 190, 220);
      textAlign(LEFT, CENTER);
      text(hiddenTags[j], colMidX + 8, y);
    }

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
// Action Potential Entity
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
