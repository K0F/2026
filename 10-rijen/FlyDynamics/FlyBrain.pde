// =============================================================================
// FlyBrain.pde - Diptera Cognitive Model: Epigenetics, Sigmoidal Needs & Aero Plasticity
// =============================================================================
// Features:
// 1. Sigmoidal Homeostatic Decision Engine:
//    - Evaluates competitive physiological drives through sigmoid activation functions:
//      sigma(x, k, x0) = 1 / (1 + exp(-k * (x - x0)))
//    - Determines dominant goal (Sugar, Protein, Dew, Warmth, Mate, Groom, Escape)
// 2. Stimulus Flight Direction Engine:
//    - Working memory target guidance
//    - Anemotactic upwind plume surge when scent is detected
//    - Crosswind casting sweep in turbulent flow fields to intercept plumes
// 3. Adaptive Aero-Navigation Plasticity:
//    - Plastic crab-angle compensation (wCrabComp) against crosswinds
//    - Vertical pitch trim (wPitchTrim) against downdrafts / surfing thermals
//    - Gyroscopic haltere stabilization (wGyroDamping)
// 4. Transgenerational Epigenetic Inheritance & Speciation:
//    - Parental experience tags passed into eggs
//    - Offspring born with pre-primed aero skills and sensory affinities
//    - Speciation divergence: Musca d. aeronavis, vorax, fecundis, vigilans, hydrotropica
// =============================================================================

// Distinct Model Behaviors
final int BEHAVIOR_CRUISE = 0;           // Steady straight cruising with occasional saccades
final int BEHAVIOR_TARGET_SUGAR = 1;     // Flight towards sugar (sucrose fuel)
final int BEHAVIOR_TARGET_PROTEIN = 2;   // Flight towards protein substrate (yeast)
final int BEHAVIOR_TARGET_DEW = 3;       // Flight towards condensation dew
final int BEHAVIOR_TARGET_PERCH = 4;     // Flight to warm ceiling wire for torpor
final int BEHAVIOR_PRECISION_LAND = 5;   // Controlled deceleration & touchdown on food
final int BEHAVIOR_FEEDING = 6;          // Proboscis extension feeding
final int BEHAVIOR_GROOMING = 7;         // Systematic hygiene cleaning
final int BEHAVIOR_COURTSHIP = 8;        // Male pursuit and unilateral wing song
final int BEHAVIOR_ESCAPE = 9;           // Giant Fiber evasive catapult jump

// Epigenetic Mark Indices
final int EPI_AERO = 0;       // Aerodynamic flight experience in turbulent wind
final int EPI_SUCROSE = 1;    // Sucrose foraging experience
final int EPI_PROTEIN = 2;    // Protein / vitellogenesis experience
final int EPI_VIGILANCE = 3;  // Threat escape experience
final int NUM_EPI_MARKS = 4;

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
  float memSugarConf = 0.0;

  PVector memProteinLoc = null;
  float memProteinConf = 0.0;

  PVector memDewLoc = null;
  float memDewConf = 0.0;

  PVector memPerchLoc = new PVector(0, 0, 440);
  float memPerchConf = 0.8;

  // Active Navigation Target & Stimulus Direction
  PVector activeTarget = null;
  String targetDescription = "NONE";
  PVector stimulusDirection = new PVector(1, 0, 0);
  String stimulusStrategy = "STEADY CRUISE";

  // Sigmoidal Needs / Urgencies
  float driveSugar = 0;
  float driveProtein = 0;
  float driveDew = 0;
  float driveWarmth = 0;
  float driveMate = 0;
  float driveGroom = 0;
  float driveEscape = 0;

  // Aerodynamic Navigation Plasticity
  float aeroSkill = 0.14;          // 0.0 to 1.0 (mastery of turbulent flight)
  float inheritedAeroSkill = 0.12; // Epigenetically inherited baseline
  float wCrabComp = 0.18;          // Crosswind crab-angle compensation weight
  float wPitchTrim = 0.18;         // Vertical draft trim weight
  float wGyroDamping = 0.22;       // Haltere gyroscopic stabilization weight
  float crabAngle = 0.0;           // Active crab angle offset (radians)
  float pitchTrim = 0.0;           // Active pitch trim offset (radians)
  float airSlip = 0.0;             // Sensed crosswind slip angle (radians)
  float groundTrackAlignment = 0.0;// Alignment of velocity with stimulus direction

  // SIMPLE REASONING LAYER (Central Complex Fan-Shaped Body Deliberation)
  final int TACTIC_DIRECT = 0;       // Direct feasible execution
  final int TACTIC_CORNER_ESCAPE = 1;// Corner confinement detected -> Escape to arena center
  final int TACTIC_TACK_EDDY = 2;    // Counter-eddy opposing track -> Tack around vortex
  final int TACTIC_CONSERVE_FUEL = 3;// Fuel insufficient for flight -> Low-altitude glide/crawl
  final int TACTIC_FALSIFY = 4;      // Resource absent at memory site -> Invalidate belief & cast plume
  
  int reasoningTactic = TACTIC_DIRECT;
  String reasoningVerdict = "FEASIBLE: ASSESSING TERRARIUM";
  float targetFeasibility = 1.0;
  float estimatedFuelCost = 0.0;
  float cornerTrapTimer = 0.0;
  float stallTimer = 0.0;
  float prevDistToGoal = 9999.0;
  boolean shouldForceTakeoff = false;

  // Transgenerational Epigenetics & Speciation
  float[] epigeneticMarks = new float[NUM_EPI_MARKS];
  int generation = 0;
  String speciesName = "Musca domestica";
  String subspecies = "typica";
  color speciesChitinColor = color(55, 60, 68);
  float wingAspectMod = 1.0;

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
    for (int i = 0; i < NUM_EPI_MARKS; i++) epigeneticMarks[i] = 0.10;
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

  // Sigmoidal Mathematical Activation Function
  float sigmoid(float x, float k, float x0) {
    return 1.0 / (1.0 + exp(-k * (x - x0)));
  }

  // Visual & Tarsal Working Memory
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

  // ---------------------------------------------------------------------------
  // Cognitive Deliberation & Sigmoidal Decision Engine
  // ---------------------------------------------------------------------------
  void computeThinking(float visL, float visR, float loom, float carbOdor, float proteinOdor, 
                       float pheromone, float tarsalSugar, float haltereGyro, float compass, 
                       float hunger, float eggUrge, float thirst, 
                       PVector flyPos, float flyHeading, float flyTemp, int flyState, boolean isFemale,
                       Environment env, PVector wind, float trehalose) {
    // 1. Sensory Influx
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

    // Working Memory Decay
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

    // 3. Hidden Layer Recurrent Integrator
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

    // 4. Sigmoidal Need Decision & Stimulus Direction Calculation
    evaluateSigmoidalNeedsAndDirection(flyPos, flyHeading, flyTemp, flyState, isFemale, env, wind, carbOdor, proteinOdor, pheromone, loom);

    // 5. Simple Reasoning Layer: Evaluates Confinement, Cost Feasibility & Beliefs
    runReasoningLayer(flyPos, flyHeading, flyTemp, flyState, isFemale, env, wind, trehalose);

    // 6. Motor Outputs
    for (int k = 0; k < NUM_OUTPUTS; k++) {
      float sum = 0;
      for (int j = 0; j < NUM_HIDDEN; j++) {
        sum += max(0, hidden[j]) * wHiddenOutput[j][k];
      }

      // Proportional drive according to active deliberate target
      if (hasActiveTarget() || activeBehavior == BEHAVIOR_TARGET_SUGAR || activeBehavior == BEHAVIOR_TARGET_PROTEIN || activeBehavior == BEHAVIOR_TARGET_DEW) {
        if (k == 0) sum += 1.4; // Strong forward cruise thrust
        if (k == 3) sum += 1.6; // Voluntary takeoff jump if landed
      }

      if (shouldForceTakeoff) {
        if (k == 3) sum += 3.8; // Force jump takeoff to escape corner trap
      }

      outputs[k] = 1.0 / (1.0 + exp(-sum));
    }

    // Nerve Action Potentials
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

  // ---------------------------------------------------------------------------
  // Sigmoidal Drive Valuation & Stimulus Flight Direction
  // ---------------------------------------------------------------------------
  void evaluateSigmoidalNeedsAndDirection(PVector flyPos, float flyHeading, float flyTemp, int flyState, 
                                          boolean isFemale, Environment env, PVector wind, 
                                          float carbOdor, float proteinOdor, float pheromone, float loom) {
    // 1. Calculate Sigmoidal Need Potentials
    driveEscape = sigmoid(loom, 16.0, 0.28) * 12.0;
    driveSugar = sigmoid(inputs[9], 8.5, 0.38) * (1.0 + 0.65 * memSugarConf);
    driveProtein = isFemale ? (sigmoid(inputs[10], 8.5, 0.35) * (1.0 + 0.65 * memProteinConf)) : 0.0;
    driveDew = sigmoid(inputs[11], 9.0, 0.42) * (1.0 + 0.50 * memDewConf);
    driveWarmth = sigmoid(23.2 - flyTemp, 3.2, 2.4);
    driveMate = (!isFemale) ? sigmoid(pheromone, 7.5, 0.30) : 0.0;
    driveGroom = sigmoid(1.0 - inputs[6], 8.0, 0.52);

    // 2. Behavioral Priority Arbitration
    if (driveEscape > 2.0) {
      activeBehavior = BEHAVIOR_ESCAPE;
      activeTarget = null;
      targetDescription = "EVADE THREAT";
      stimulusStrategy = "GIANT FIBER JUMP AWAY";
      stimulusDirection.set(-cos(flyHeading), -sin(flyHeading), 0.8);
      stimulusDirection.normalize();
      currentThought = "! GIANT FIBER EVASIVE ESCAPE !";
      thoughtColor = color(255, 45, 45);
      epigeneticMarks[EPI_VIGILANCE] = min(1.0, epigeneticMarks[EPI_VIGILANCE] + 0.001);
      return;
    }

    if (flyState == 4 || inputs[6] > 0.5) { // STATE_FEEDING
      activeBehavior = BEHAVIOR_FEEDING;
      activeTarget = null;
      targetDescription = "FEEDING";
      stimulusStrategy = "PROBOSCIS CONTACT";
      currentThought = "PROBOSCIS SUCROSE INGESTION";
      thoughtColor = color(255, 205, 50);
      return;
    }

    // Dominant competitive need
    float maxDrive = max(driveSugar, max(driveProtein, max(driveDew, max(driveWarmth, max(driveMate, driveGroom)))));

    if (maxDrive < 0.22) {
      activeBehavior = BEHAVIOR_CRUISE;
      activeTarget = null;
      targetDescription = "SURVEYING ARENA";
      stimulusStrategy = "INTER-SACCADIC CRUISE";
      stimulusDirection.set(cos(flyHeading), sin(flyHeading), 0);
      currentThought = "STEADY CRUISE & SURVEY";
      thoughtColor = color(150, 210, 255);
      return;
    }

    // 3. Fulfill Dominant Need & Calculate Flight Vector to Stimulus
    if (maxDrive == driveSugar) {
      activeBehavior = BEHAVIOR_TARGET_SUGAR;
      epigeneticMarks[EPI_SUCROSE] = min(1.0, epigeneticMarks[EPI_SUCROSE] + 0.0002);

      if (memSugarLoc != null && memSugarConf > 0.2) {
        activeTarget = memSugarLoc;
        targetDescription = "SUCROSE (" + int(memSugarConf * 100) + "%)";
        stimulusStrategy = "WORKING MEMORY LOCK";
        stimulusDirection = PVector.sub(memSugarLoc, flyPos);
        stimulusDirection.normalize();
      } else if (carbOdor > 0.06) {
        activeTarget = null;
        targetDescription = "SUGAR ODOR PLUME";
        stimulusStrategy = "UPWIND ANEMOTAXIS SURGE";
        stimulusDirection.set(-wind.x, -wind.y, -wind.z * 0.4);
        stimulusDirection.normalize();
      } else {
        activeTarget = null;
        targetDescription = "FORAGING SUCROSE";
        stimulusStrategy = "CROSSWIND CASTING SWEEP";
        float castSide = (sin(frameCount * 0.03 + internalCompassAngle) > 0) ? 1.0 : -1.0;
        stimulusDirection.set(-wind.y * castSide, wind.x * castSide, random(-0.2, 0.2));
        stimulusDirection.normalize();
      }
      currentThought = "SUGAR NEED: " + stimulusStrategy;
      thoughtColor = color(255, 215, 60);

    } else if (maxDrive == driveProtein) {
      activeBehavior = BEHAVIOR_TARGET_PROTEIN;
      epigeneticMarks[EPI_PROTEIN] = min(1.0, epigeneticMarks[EPI_PROTEIN] + 0.0002);

      if (memProteinLoc != null && memProteinConf > 0.2) {
        activeTarget = memProteinLoc;
        targetDescription = "YEAST SUBSTRATE";
        stimulusStrategy = "WORKING MEMORY LOCK";
        stimulusDirection = PVector.sub(memProteinLoc, flyPos);
        stimulusDirection.normalize();
      } else if (proteinOdor > 0.06) {
        activeTarget = null;
        targetDescription = "YEAST PLUME";
        stimulusStrategy = "UPWIND ANEMOTAXIS SURGE";
        stimulusDirection.set(-wind.x, -wind.y, -wind.z * 0.4);
        stimulusDirection.normalize();
      } else {
        activeTarget = null;
        targetDescription = "SEARCHING PROTEIN";
        stimulusStrategy = "CROSSWIND CASTING SWEEP";
        float castSide = (sin(frameCount * 0.035) > 0) ? 1.0 : -1.0;
        stimulusDirection.set(-wind.y * castSide, wind.x * castSide, random(-0.2, 0.2));
        stimulusDirection.normalize();
      }
      currentThought = "OOGENESIS PROTEIN: " + stimulusStrategy;
      thoughtColor = color(235, 75, 140);

    } else if (maxDrive == driveDew) {
      activeBehavior = BEHAVIOR_TARGET_DEW;
      if (memDewLoc != null && memDewConf > 0.2) {
        activeTarget = memDewLoc;
        targetDescription = "GLASS DEW";
        stimulusStrategy = "WORKING MEMORY LOCK";
        stimulusDirection = PVector.sub(memDewLoc, flyPos);
        stimulusDirection.normalize();
      } else {
        activeTarget = null;
        targetDescription = "GLASS MOISTURE";
        stimulusStrategy = "PERIMETER WALL HEADING";
        float wallX = (flyPos.x > 0) ? env.cubeW * 0.48 : -env.cubeW * 0.48;
        stimulusDirection.set(wallX - flyPos.x, 0, random(-0.15, 0.15));
        stimulusDirection.normalize();
      }
      currentThought = "THIRST: " + stimulusStrategy;
      thoughtColor = color(70, 210, 240);

    } else if (maxDrive == driveWarmth) {
      activeBehavior = BEHAVIOR_TARGET_PERCH;
      activeTarget = memPerchLoc;
      targetDescription = "WARM PERCH";
      stimulusStrategy = "THERMOTACTIC UPWARD ASCENT";
      stimulusDirection.set(env.lightPos.x - flyPos.x, env.lightPos.y - flyPos.y, env.cubeH - flyPos.z);
      stimulusDirection.normalize();
      currentThought = "BASKING: ASCENDING TO WARM CEILING";
      thoughtColor = color(255, 180, 70);

    } else if (maxDrive == driveMate) {
      activeBehavior = BEHAVIOR_COURTSHIP;
      activeTarget = null;
      targetDescription = "PHEROMONE TRAIL";
      stimulusStrategy = "UPWIND PHEROMONE PURSUIT";
      stimulusDirection.set(-wind.x, -wind.y, random(-0.2, 0.2));
      stimulusDirection.normalize();
      currentThought = "COURTSHIP PURSUIT & 165 HZ WING BUZZ";
      thoughtColor = color(140, 110, 255);

    } else {
      activeBehavior = BEHAVIOR_GROOMING;
      activeTarget = null;
      targetDescription = "HYGIENE";
      stimulusStrategy = "SYSTEMATIC CLEANING";
      stimulusDirection.set(0, 0, 0);
      currentThought = "GROOMING SENSORY BRISTLES";
      thoughtColor = color(80, 230, 130);
    }
  }

  // ---------------------------------------------------------------------------
  // Simple Reasoning Layer (Central Complex FB: Confinement, Feasibility & Beliefs)
  // ---------------------------------------------------------------------------
  void runReasoningLayer(PVector flyPos, float flyHeading, float flyTemp, int flyState, 
                         boolean isFemale, Environment env, PVector wind, float trehalose) {
    shouldForceTakeoff = false;

    // 1. Survival Check: Looming Threat Override
    if (inputs[2] > 0.3) {
      reasoningTactic = TACTIC_DIRECT;
      reasoningVerdict = "SURVIVAL: Looming threat -> Catapult escape jump.";
      return;
    }

    // 2. Corner Trap & Spatial Confinement Reasoning:
    // Prevents flies from accumulating or stopping at terrarium corners!
    float distLeft = flyPos.x - (-env.cubeW * 0.5);
    float distRight = env.cubeW * 0.5 - flyPos.x;
    float distBack = flyPos.y - (-env.cubeD * 0.5);
    float distFront = env.cubeD * 0.5 - flyPos.y;

    boolean inCorner = (min(distLeft, distRight) < 70 && min(distBack, distFront) < 70);

    if (inCorner) {
      cornerTrapTimer += 0.016;
      reasoningTactic = TACTIC_CORNER_ESCAPE;
      reasoningVerdict = "CORNER TRAP: Corner confinement -> Repelling to arena center.";
      thoughtColor = color(255, 130, 40);

      // Force flight vector straight into the open arena center with upward lift:
      stimulusDirection.set(-flyPos.x * 0.8, -flyPos.y * 0.8, max(40, 160 - flyPos.z));
      stimulusDirection.normalize();
      stimulusStrategy = "CORNER ESCAPE TO CENTER";

      // If fly is crawling/resting in a corner for more than 0.3s, force immediate voluntary takeoff!
      if (flyState != 0) { // Not flying
        shouldForceTakeoff = true;
      }
      return;
    } else {
      cornerTrapTimer = max(0, cornerTrapTimer - 0.05);
    }

    // 3. Belief Validation (False Expectation Mismatch):
    if (activeTarget != null) {
      float distToTarget = dist(flyPos.x, flyPos.y, flyPos.z, activeTarget.x, activeTarget.y, activeTarget.z);
      if (distToTarget < 30) {
        boolean foodFound = false;
        for (Food f : env.foods) {
          if (PVector.dist(f.pos, activeTarget) < 36) {
            foodFound = true;
            break;
          }
        }
        if (!foodFound && (activeBehavior == BEHAVIOR_TARGET_SUGAR || activeBehavior == BEHAVIOR_TARGET_PROTEIN)) {
          reasoningTactic = TACTIC_FALSIFY;
          reasoningVerdict = "BELIEF FALSIFIED: Resource depleted at site -> Invalidate memory & cast plume.";
          thoughtColor = color(240, 100, 100);

          if (activeBehavior == BEHAVIOR_TARGET_SUGAR) {
            memSugarConf = 0.0;
            memSugarLoc = null;
          } else {
            memProteinConf = 0.0;
            memProteinLoc = null;
          }
          activeTarget = null;
          stimulusStrategy = "CROSSWIND PLUME CASTING";
          float castSide = (sin(frameCount * 0.04) > 0) ? 1.0 : -1.0;
          stimulusDirection.set(-wind.y * castSide, wind.x * castSide, random(-0.2, 0.2));
          stimulusDirection.normalize();
          return;
        }
      }
    }

    // 4. Energy Feasibility & Cost-Benefit Check:
    float targetDist = (activeTarget != null) ? PVector.dist(flyPos, activeTarget) : 180.0;
    float headwind = wind.x * (-stimulusDirection.x) + wind.y * (-stimulusDirection.y);
    estimatedFuelCost = targetDist * 0.0011 * (1.0 + max(0, headwind) * 0.45);

    if (trehalose < estimatedFuelCost && trehalose < 0.26) {
      targetFeasibility = trehalose / max(0.01, estimatedFuelCost);
      reasoningTactic = TACTIC_CONSERVE_FUEL;
      reasoningVerdict = "FUEL DEFICIT: Cost " + nf(estimatedFuelCost, 0, 2) + " > Treh " + nf(trehalose, 0, 2) + " -> Low altitude crawl foraging.";
      thoughtColor = color(255, 175, 50);

      stimulusDirection.z = -0.4;
      stimulusDirection.normalize();
      return;
    } else {
      targetFeasibility = 1.0;
    }

    // 5. Stagnation / Eddy Opposition Check:
    if (flyState == 0) { // STATE_FLYING
      float curDist = (activeTarget != null) ? PVector.dist(flyPos, activeTarget) : 120.0;
      float progress = prevDistToGoal - curDist;
      if (progress < 0.10 && activeBehavior != BEHAVIOR_CRUISE) {
        stallTimer += 0.016;
        if (stallTimer > 1.3) {
          reasoningTactic = TACTIC_TACK_EDDY;
          reasoningVerdict = "TURBULENCE STALL: Counter-eddy opposing track -> Tacking 35 deg around vortex.";
          thoughtColor = color(100, 210, 255);

          float tackAng = radians(35);
          float nx = stimulusDirection.x * cos(tackAng) - stimulusDirection.y * sin(tackAng);
          float ny = stimulusDirection.x * sin(tackAng) + stimulusDirection.y * cos(tackAng);
          stimulusDirection.set(nx, ny, -0.1);
          stimulusDirection.normalize();
          return;
        }
      } else {
        stallTimer = max(0, stallTimer - 0.04);
      }
      prevDistToGoal = curDist;
    }

    // 6. Feasible Direct Execution
    reasoningTactic = TACTIC_DIRECT;
    reasoningVerdict = "FEASIBLE: Track +" + nf(groundTrackAlignment, 0, 2) + " | Cost " + nf(estimatedFuelCost, 0, 2) + " < Budget " + nf(trehalose, 0, 2);
  }

  // ---------------------------------------------------------------------------
  // Adaptive Aero-Navigation & Plasticity Controller
  // ---------------------------------------------------------------------------
  void updateAirNavigation(Fly fly, Environment env, PVector wind) {
    // 1. Sensed Aerodynamic Variables
    float targetTrackYaw = atan2(stimulusDirection.y, stimulusDirection.x);
    float crosswind = wind.x * sin(targetTrackYaw) - wind.y * cos(targetTrackYaw);
    float groundSpeed = sqrt(fly.vel.x * fly.vel.x + fly.vel.y * fly.vel.y);
    float actualTrackYaw = atan2(fly.vel.y, fly.vel.x);
    airSlip = atan2(sin(fly.heading - actualTrackYaw), cos(fly.heading - actualTrackYaw));

    // 2. Compute Learned Crab-Angle Compensation
    float estimatedThrust = max(1.5, groundSpeed);
    float idealCrab = -crosswind / estimatedThrust;
    idealCrab = constrain(idealCrab, -0.75, 0.75);

    crabAngle = lerp(crabAngle, idealCrab * wCrabComp, 0.14);
    pitchTrim = lerp(pitchTrim, -wind.z * 0.18 * wPitchTrim, 0.12);

    // 3. Evaluate Ground Track Alignment
    PVector groundTrack2D = new PVector(fly.vel.x, fly.vel.y);
    PVector targetDir2D = new PVector(stimulusDirection.x, stimulusDirection.y);
    if (groundTrack2D.mag() > 0.1 && targetDir2D.mag() > 0.1) {
      groundTrack2D.normalize();
      targetDir2D.normalize();
      groundTrackAlignment = groundTrack2D.dot(targetDir2D);
    } else {
      groundTrackAlignment = 0.5;
    }

    // 4. Hebbian / Reinforcement Plasticity for Aero-Navigation
    if (groundTrackAlignment > 0.6) {
      float alignmentReward = 0.04 * groundTrackAlignment;
      dopamineReward += alignmentReward;
      cumulativeReward += alignmentReward;

      float crabError = abs(idealCrab - crabAngle);
      wCrabComp = constrain(wCrabComp + 0.0008 * (1.0 - crabError), 0.08, 1.25);
      wPitchTrim = constrain(wPitchTrim + 0.0006, 0.08, 1.20);
      wGyroDamping = constrain(wGyroDamping + 0.0005, 0.10, 1.0);

      aeroSkill = min(1.0, aeroSkill + 0.00018);
      epigeneticMarks[EPI_AERO] = min(1.0, epigeneticMarks[EPI_AERO] + 0.00022);
    }

    // Thermal updraft fuel bonus: riding rising air saves trehalose!
    if (wind.z > 0.3) {
      fly.trehalose = min(1.0, fly.trehalose + 0.00015);
    }
  }

  // ---------------------------------------------------------------------------
  // Transgenerational Epigenetics & Speciation Divergence
  // ---------------------------------------------------------------------------
  FlyBrain mutateCopyWithEpigenetics(FlyBrain motherBrain, FlyBrain fatherBrain) {
    FlyBrain child = new FlyBrain();

    // 1. Neural Network Weight Mutation (Genetic substrate)
    for (int i = 0; i < NUM_INPUTS; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        float baseW = (fatherBrain != null) ? lerp(motherBrain.wInputHidden[i][j], fatherBrain.wInputHidden[i][j], 0.5) : motherBrain.wInputHidden[i][j];
        child.wInputHidden[i][j] = baseW + random(-0.035, 0.035);
      }
    }
    for (int i = 0; i < NUM_HIDDEN; i++) {
      for (int j = 0; j < NUM_HIDDEN; j++) {
        float baseW = (fatherBrain != null) ? lerp(motherBrain.wHiddenHidden[i][j], fatherBrain.wHiddenHidden[i][j], 0.5) : motherBrain.wHiddenHidden[i][j];
        child.wHiddenHidden[i][j] = baseW + random(-0.025, 0.025);
      }
      for (int k = 0; k < NUM_OUTPUTS; k++) {
        float baseW = (fatherBrain != null) ? lerp(motherBrain.wHiddenOutput[i][k], fatherBrain.wHiddenOutput[i][k], 0.5) : motherBrain.wHiddenOutput[i][k];
        child.wHiddenOutput[i][k] = baseW + random(-0.035, 0.035);
      }
    }

    // 2. Generation & Epigenetic Transmission
    int parentGen = max(motherBrain.generation, (fatherBrain != null) ? fatherBrain.generation : motherBrain.generation);
    child.generation = parentGen + 1;

    for (int m = 0; m < NUM_EPI_MARKS; m++) {
      float mVal = motherBrain.epigeneticMarks[m];
      float fVal = (fatherBrain != null) ? fatherBrain.epigeneticMarks[m] : mVal;
      child.epigeneticMarks[m] = constrain(lerp(mVal, fVal, 0.5) * 0.94 + random(-0.02, 0.05), 0.05, 1.0);
    }

    // 3. Experiential Priming: Offspring Born with Acquired Experience!
    child.inheritedAeroSkill = child.epigeneticMarks[EPI_AERO] * 0.75;
    child.aeroSkill = max(0.14, child.inheritedAeroSkill);
    child.wCrabComp = lerp(0.18, 0.95, child.epigeneticMarks[EPI_AERO]);
    child.wPitchTrim = lerp(0.18, 0.90, child.epigeneticMarks[EPI_AERO]);
    child.wGyroDamping = lerp(0.22, 0.85, child.epigeneticMarks[EPI_AERO]);

    if (child.epigeneticMarks[EPI_SUCROSE] > 0.35) {
      child.wInputHidden[3][0] += 0.8;
    }
    if (child.epigeneticMarks[EPI_PROTEIN] > 0.35) {
      child.wInputHidden[4][1] += 0.8;
    }
    if (child.epigeneticMarks[EPI_VIGILANCE] > 0.32) {
      child.wInputHidden[2][3] += 1.2;
    }

    // 4. Speciation Classifier
    child.evaluateSpeciation();

    return child;
  }

  void evaluateSpeciation() {
    float aero = epigeneticMarks[EPI_AERO];
    float sucrose = epigeneticMarks[EPI_SUCROSE];
    float protein = epigeneticMarks[EPI_PROTEIN];
    float vigilance = epigeneticMarks[EPI_VIGILANCE];

    if (aero > 0.45 && aero >= sucrose && aero >= protein && aero >= vigilance) {
      speciesName = "Musca d. aeronavis";
      subspecies = "aeronavis (Turbulence Glider)";
      speciesChitinColor = color(50, 80, 115);
      wingAspectMod = 1.18;

    } else if (sucrose > 0.45 && sucrose >= aero && sucrose >= protein && sucrose >= vigilance) {
      speciesName = "Musca d. vorax";
      subspecies = "vorax (Sucrose Forager)";
      speciesChitinColor = color(100, 75, 40);
      wingAspectMod = 1.0;

    } else if (protein > 0.45 && protein >= aero && protein >= sucrose && protein >= vigilance) {
      speciesName = "Musca d. fecundis";
      subspecies = "fecundis (Vitellogenic Breeder)";
      speciesChitinColor = color(95, 45, 65);
      wingAspectMod = 0.95;

    } else if (vigilance > 0.38) {
      speciesName = "Musca d. vigilans";
      subspecies = "vigilans (Hyper-Vigilant)";
      speciesChitinColor = color(25, 28, 34);
      wingAspectMod = 1.05;

    } else {
      speciesName = "Musca domestica";
      subspecies = "typica (Generalist)";
      speciesChitinColor = color(55, 60, 68);
      wingAspectMod = 1.0;
    }
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
  // Right HUD Panel: Spatial Memory, Epigenetics, CX Compass & Learning Oscilloscope
  // ---------------------------------------------------------------------------
  void displayLearningHUD(float px, float py, float pw, float ph) {
    pushStyle();
    fill(10, 16, 26);
    stroke(55, 95, 140);
    strokeWeight(1);
    rect(px, py, pw, ph);

    fill(180, 225, 255);
    textAlign(LEFT, TOP);
    text("COGNITIVE CENTRAL COMPLEX & EPIGENETICS", px + 8, py + 8);

    if (dopamineReward > 0.05) {
      fill(255, 215, 50);
      noStroke();
      rect(px + pw - 88, py + 7, 80, 12);
      fill(10, 16, 26);
      textAlign(CENTER, CENTER);
      text("+DOPAMINE", px + pw - 48, py + 12);
    }

    fill(130, 185, 235);
    textAlign(LEFT, TOP);
    text("GEN: F" + generation + "  |  " + subspecies, px + 8, py + 22);
    text("STRATEGY: " + stimulusStrategy + " (" + targetDescription + ")", px + 8, py + 34);

    float oscX = px + 8;
    float oscY = py + 48;
    float oscW = pw - 90;
    float oscH = 42;

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

    float ringX = px + pw - 44;
    float ringY = py + 69;

    fill(6, 10, 16);
    stroke(40, 70, 105);
    rect(ringX - 35, oscY, 70, oscH);

    fill(160, 195, 230);
    textAlign(CENTER, TOP);
    text("RING CX", ringX, oscY + 2);

    for (int i = 0; i < 8; i++) {
      float a = map(i, 0, 8, 0, TWO_PI) - HALF_PI;
      float wx = ringX + cos(a) * 13;
      float wy = (ringY + 4) + sin(a) * 10;
      fill(lerpColor(color(20, 35, 50), color(90, 220, 255), ringAttractor[i]));
      noStroke();
      rect(wx - 2, wy - 2, 4, 4);
    }

    stroke(255, 205, 50);
    strokeWeight(1.5);
    line(ringX, ringY + 4, ringX + cos(internalCompassAngle - HALF_PI) * 11, (ringY + 4) + sin(internalCompassAngle - HALF_PI) * 9);

    float aeroY = py + 94;
    fill(140, 180, 220);
    textAlign(LEFT, TOP);
    text("AERO SKILL: " + int(aeroSkill * 100) + "% (INHERITED +" + int(inheritedAeroSkill * 100) + "%) | CRAB: " + nf(degrees(crabAngle), 0, 1) + " DEG", px + 8, aeroY);

    float epiY = aeroY + 14;
    fill(100, 190, 240);
    text("EPI-AERO:" + int(epigeneticMarks[EPI_AERO] * 100) + "%  SUC:" + int(epigeneticMarks[EPI_SUCROSE] * 100) + "%  PROT:" + int(epigeneticMarks[EPI_PROTEIN] * 100) + "%  VIG:" + int(epigeneticMarks[EPI_VIGILANCE] * 100) + "%", px + 8, epiY);

    float netStartY = epiY + 16;
    float netH = ph - (netStartY - py) - 8;
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
            stroke(w > 0 ? color(70, 210, 110, 130) : color(240, 70, 70, 130));
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
            stroke(w > 0 ? color(90, 230, 140, 150) : color(240, 90, 90, 150));
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
