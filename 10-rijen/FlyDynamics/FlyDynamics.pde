// =============================================================================
// FlyDynamics.pde - Diptera Neuro-Ethology & Biomechanics Laboratory
// =============================================================================
// An interactive laboratory for studying Diptera behavior, biomechanics, and cycles:
// - Hexapod alternating tripod motorics, grooming, and jump-takeoff kinematics
// - Dual nutritional bioenergetics: Trehalose (flight sugar) vs Protein (vitellogenesis)
// - Reproductive cycle: Courtship wing song -> Egg clutches -> Feeding larvae -> Adult eclosion
// - Circadian photoperiod cycle (Day/Night torpor)
// - Neuromorphic micro-brain (CTRNN + Mushroom Body dopamine plasticity)
// - Low-res compound eye ommatidia vision with looming optical flow detection
// =============================================================================

Environment env;
ArrayList<Fly> swarm;
IsoCamera cam;

// Laboratory State & Controls
int selectedIndex = 0;
boolean showBrainHUD = true;
boolean showVisionHUD = true;
boolean macroFocusMode = false;
boolean simulationPaused = false;
int swarmInitialSize = 12;

// Circadian Photoperiod Cycle (Day / Night)
float dayNightTime = 0.25; // 0.0 to 1.0 (0.25 = noon, 0.75 = midnight)
boolean circadianAutoCycle = true;
color dayAmbient = color(14, 18, 26);
color nightAmbient = color(6, 8, 12);

// Real-time Ethology Laboratory Notebook (Event Log)
ArrayList<String> labLog = new ArrayList<String>();

void setup() {
  size(1360, 860);
  surface.setTitle("Diptera Ethology & Neuro-Biomechanics Laboratory (Processing 4)");
  frameRate(60);
  smooth();

  cam = new IsoCamera(width / 2 - 80, height / 2 - 30, 0.95);
  env = new Environment();
  swarm = new ArrayList<Fly>();

  // Spawn balanced initial cohort (females and males)
  for (int i = 0; i < swarmInitialSize; i++) {
    float rx = random(-env.cubeW * 0.38, env.cubeW * 0.38);
    float ry = random(-env.cubeD * 0.38, env.cubeD * 0.38);
    float rz = (i % 3 == 0) ? 0 : random(30, env.cubeH * 0.75);
    Fly f = new Fly(rx, ry, rz);
    f.isFemale = (i % 2 == 0); // 50/50 sex ratio
    f.bodyScale = f.isFemale ? 1.05 : 0.92;
    f.abdomenScale = f.isFemale ? 1.15 : 0.85;
    if (rz == 0) f.state = STATE_CRAWLING;
    swarm.add(f);
  }

  logEvent("Laboratory initialized with cohort of " + swarmInitialSize + " Diptera specimens.");
  logEvent("Environmental chambers: Sugar Dispenser, Yeast Substrate, Condensation dew.");
}

void draw() {
  // Circadian photoperiod progression
  if (circadianAutoCycle && !simulationPaused) {
    dayNightTime = (dayNightTime + 0.00015) % 1.0;
  }
  float sunFactor = max(0, sin(dayNightTime * TWO_PI));
  color currentSky = lerpColor(nightAmbient, dayAmbient, sunFactor);
  background(currentSky);

  // 1. UPDATE ENVIRONMENT & ENTITIES
  if (!simulationPaused) {
    env.update();

    // Metamorphosis: Larvae pupate into adult flies
    for (int i = env.larvae.size() - 1; i >= 0; i--) {
      Larva larva = env.larvae.get(i);
      if (larva.isReadyToPupate() && swarm.size() < 28) {
        // Eclosion: adult fly emerges from puparium!
        Fly adult = new Fly(larva.pos.x, larva.pos.y, 0, larva.inheritedBrain);
        adult.state = STATE_CRAWLING;
        adult.trehalose = 0.95;
        swarm.add(adult);
        env.larvae.remove(i);
        logEvent("Eclosion: Larva metamorphosed into adult " + (adult.isFemale ? "♀" : "♂") + " Fly #" + swarm.size());
      }
    }

    // Update all flies
    for (int i = 0; i < swarm.size(); i++) {
      Fly f = swarm.get(i);
      f.update(env, swarm);
      
      // Nighttime torpor on ceiling wire or warm corner
      if (sunFactor < 0.15 && f.pos.z > env.cubeH * 0.7 && f.state == STATE_CRAWLING) {
        f.state = STATE_GROOMING; // Restful torpor
      }
    }
  }

  // Camera tracking in Macro Focus Mode
  if (macroFocusMode && selectedIndex < swarm.size()) {
    Fly sel = swarm.get(selectedIndex);
    cam.targetZoom = 2.4;
    cam.targetOrigin.set(width/2 - sel.pos.x * 1.6 - 60, height/2 - sel.pos.y * 0.8 + sel.pos.z * 1.2);
  } else {
    cam.targetZoom = 0.95;
    cam.targetOrigin.set(width/2 - 80, height/2 - 30);
  }
  cam.update();

  // 2. RENDER 3D TERRARIUM CUBE & ENTITIES
  env.displayCube(cam);

  // Render all flies in isometric perspective
  for (int i = 0; i < swarm.size(); i++) {
    Fly f = swarm.get(i);
    boolean isSelected = (i == selectedIndex);
    f.display(cam, isSelected);
  }

  // 3. RENDER LABORATORY TELEMETRY & NOTEBOOK
  displayHeaderBar(sunFactor);
  displayLabNotebook(20, 52, 280, 160);

  Fly selFly = (selectedIndex < swarm.size()) ? swarm.get(selectedIndex) : null;
  if (selFly != null) {
    // Bio-telemetry Card of Selected Specimen
    displaySpecimenCard(selFly, 20, 222, 280, 215);

    // Compound Eye Low-Res Vision Viewport (Bottom Left)
    if (showVisionHUD) {
      selFly.vision.displayHUD(20, height - 170, 320, 150);
    }

    // Neural Reasoning Brain & Anatomical Fly Viewport (Bottom Right)
    if (showBrainHUD) {
      selFly.brain.displayHUD(width - 610, height - 235, 590, 218);
    }
  }
}

// -----------------------------------------------------------------------------
// Header Bar & Lab Status
// -----------------------------------------------------------------------------
void displayHeaderBar(float sunFactor) {
  pushStyle();
  fill(10, 15, 24, 225);
  noStroke();
  rect(0, 0, width, 44);
  stroke(60, 120, 185, 120);
  strokeWeight(1);
  line(0, 44, width, 44);

  // Title
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13.5);
  text("DIPTERA ETHOLOGY & NEURO-BIOMECHANICS LABORATORY", 20, 22);

  // Cohort & Life Stage Telemetry
  int females = 0;
  int males = 0;
  int airborne = 0;
  for (Fly f : swarm) {
    if (f.isFemale) females++; else males++;
    if (f.state == STATE_FLYING || f.state == STATE_TAKEOFF) airborne++;
  }

  fill(130, 195, 255);
  textSize(11);
  String diurnalPhase = (sunFactor > 0.5) ? "DAY [12:00]" : (sunFactor > 0.1 ? "TWILIGHT" : "NIGHT (TORPOR)");
  text("POPULATION: " + swarm.size() + " (♀" + females + " ♂" + males + ")  |  EGGS: " + env.eggs.size() + "  |  LARVAE: " + env.larvae.size() + "  |  AIR: " + airborne + "  |  CYCLE: " + diurnalPhase, 400, 22);

  // Hotkey actions legend
  textAlign(RIGHT, CENTER);
  fill(175, 190, 210);
  textSize(9.5);
  text("[1] Sugar  [2] Protein  [3] Dew  [W] Wind  [D] Day/Night  [F] Threat  [TAB] Macro  [P] Pause", width - 20, 22);
  popStyle();
}

// -----------------------------------------------------------------------------
// Real-Time Ethology Laboratory Notebook (Event Log)
// -----------------------------------------------------------------------------
void displayLabNotebook(float px, float py, float pw, float ph) {
  pushStyle();
  fill(10, 16, 26, 220);
  stroke(60, 110, 175, 140);
  strokeWeight(1);
  rect(px, py, pw, ph, 6);

  // Header
  fill(180, 220, 255);
  textAlign(LEFT, TOP);
  textSize(10);
  text("ETHOLOGY NOTEBOOK / BEHAVIORAL LOG", px + 10, py + 8);

  // Display most recent log entries
  float logY = py + 26;
  textSize(8.5);
  int startIdx = max(0, labLog.size() - 7);
  for (int i = startIdx; i < labLog.size(); i++) {
    fill(145, 185, 225);
    text(labLog.get(i), px + 10, logY);
    logY += 17;
  }
  popStyle();
}

void logEvent(String entry) {
  String timeStamp = nf(minute(), 2) + ":" + nf(second(), 2);
  labLog.add("[" + timeStamp + "] " + entry);
  if (labLog.size() > 40) labLog.remove(0);
}

// -----------------------------------------------------------------------------
// Specimen Bio-Telemetry Card
// -----------------------------------------------------------------------------
void displaySpecimenCard(Fly f, float px, float py, float pw, float ph) {
  pushStyle();
  fill(10, 16, 26, 225);
  stroke(60, 120, 185, 150);
  strokeWeight(1);
  rect(px, py, pw, ph, 6);

  // Specimen Title & Sex
  fill(190, 225, 255);
  textAlign(LEFT, TOP);
  textSize(10.5);
  String sexTitle = f.isFemale ? "SPECIMEN #" + (selectedIndex + 1) + " (♀ FEMALE)" : "SPECIMEN #" + (selectedIndex + 1) + " (♂ MALE)";
  text(sexTitle, px + 10, py + 8);

  // State Tag
  fill(255, 210, 80);
  textAlign(RIGHT, TOP);
  textSize(9);
  String stateStr = getStateName(f.state);
  text(stateStr, px + pw - 10, py + 9);

  // Telemetry Bars
  float rowY = py + 30;
  float rowSpacing = 20;

  drawTelemetryBar("Trehalose (Fuel)", f.trehalose, color(255, 205, 50), px + 10, rowY, pw - 20);
  rowY += rowSpacing;

  if (f.isFemale) {
    drawTelemetryBar("Protein / Oogenesis", f.protein, color(230, 80, 160), px + 10, rowY, pw - 20);
  } else {
    drawTelemetryBar("Courtship Drive", f.brain.inputs[5], color(140, 120, 255), px + 10, rowY, pw - 20);
  }
  rowY += rowSpacing;

  drawTelemetryBar("Hydration (Dew)", f.hydration, color(80, 200, 255), px + 10, rowY, pw - 20);
  rowY += rowSpacing;

  drawTelemetryBar("Sensor Cleanliness", f.cleanliness, color(90, 230, 140), px + 10, rowY, pw - 20);
  rowY += rowSpacing;

  // Temperature & Wing Beat Frequency
  fill(170, 200, 230);
  textAlign(LEFT, TOP);
  textSize(8.5);
  text("Thoracic Temp: " + nf(f.bodyTemp, 0, 1) + " °C  |  Wing Frequency: " + int(f.wingFrequency) + " Hz", px + 10, rowY + 4);
  rowY += 16;

  // Mature Eggs (Females)
  if (f.isFemale) {
    fill(255, 240, 180);
    text("Mature Eggs in Oviduct: " + f.matureEggs + " / 6 clutches", px + 10, rowY + 4);
  } else {
    fill(200, 180, 255);
    text("Acoustic Song: 165 Hz wing vibration (courtship)", px + 10, rowY + 4);
  }

  popStyle();
}

void drawTelemetryBar(String label, float val, color col, float x, float y, float w) {
  fill(150, 180, 210);
  textAlign(LEFT, CENTER);
  textSize(8.5);
  text(label, x, y + 4);

  float barX = x + 120;
  float barW = w - 120;
  fill(25, 38, 52);
  noStroke();
  rect(barX, y + 1, barW, 6, 2);

  fill(col);
  rect(barX, y + 1, barW * constrain(val, 0, 1), 6, 2);
}

String getStateName(int st) {
  switch(st) {
    case STATE_FLYING: return "AIRBORNE FLIGHT";
    case STATE_TAKEOFF: return "CATAPULT TAKEOFF";
    case STATE_LANDING: return "LANDING BRAKE";
    case STATE_CRAWLING: return "TRIPOD CRAWLING";
    case STATE_FEEDING: return "PROBOSCIS FEEDING";
    case STATE_GROOMING: return "GROOMING HYGIENE";
    case STATE_COURTSHIP: return "COURTSHIP DANCE";
    default: return "IDLE";
  }
}

// -----------------------------------------------------------------------------
// Interactive Keyboard & Laboratory Controls
// -----------------------------------------------------------------------------
void keyPressed() {
  if (key == '1') {
    // Dispense Sucrose Drop (Carbohydrate fuel) at center
    PVector p = new PVector(random(-160, 160), random(-160, 160), 0);
    env.spawnFood(p, FOOD_CARB, "Sucrose Drop", 160);
    logEvent("Dispensed Sucrose droplet (Carbohydrate flight fuel).");

  } else if (key == '2') {
    // Dispense Yeast / Decaying Protein substrate
    PVector p = new PVector(random(-160, 160), random(-160, 160), 0);
    env.spawnFood(p, FOOD_PROTEIN, "Fermenting Yeast", 220);
    logEvent("Dispensed Fermenting Yeast (Protein substrate for eggs).");

  } else if (key == '3') {
    // Add Water Condensation Dew drops on glass
    float gx = (random(1.0) > 0.5) ? env.cubeW * 0.48 : -env.cubeW * 0.48;
    env.poiList.add(new PointOfInterest(new PVector(gx, random(-100, 100), random(40, 160)), "Condensation Dew", color(80, 200, 255), POI_WATER));
    logEvent("Misted glass wall with hydration dew drops.");

  } else if (key == 'w' || key == 'W') {
    // Trigger dynamic wind gust
    env.triggerGust(random(-2.5, 2.5), random(-2.5, 2.5));
    logEvent("Wind tunnel triggered: atmospheric crosswind gust!");

  } else if (key == 'd' || key == 'D') {
    // Toggle Day / Night
    dayNightTime = (dayNightTime < 0.5) ? 0.75 : 0.25;
    logEvent("Circadian cycle shifted to: " + (dayNightTime > 0.5 ? "NIGHT" : "DAY"));

  } else if (key == 'f' || key == 'F') {
    // Looming predator swat threat
    env.threatActive = true;
    logEvent("Giant Fiber escape experiment: Looming shadow cast!");

  } else if (key == TAB) {
    // Toggle Macro Focus on selected specimen
    macroFocusMode = !macroFocusMode;

  } else if (key == 'p' || key == 'P' || key == ' ') {
    simulationPaused = !simulationPaused;

  } else if (key == 'v' || key == 'V') {
    showVisionHUD = !showVisionHUD;

  } else if (key == 'b' || key == 'B') {
    showBrainHUD = !showBrainHUD;

  } else if (key == '+' || key == '=') {
    // Add specimen
    Fly f = new Fly(random(-100, 100), random(-100, 100), 20);
    swarm.add(f);

  } else if (key == '-' || key == '_') {
    if (swarm.size() > 1) swarm.remove(swarm.size() - 1);
  }
}

void mousePressed() {
  // Select closest fly to mouse click in 3D
  float minDist = 60;
  int closest = selectedIndex;
  for (int i = 0; i < swarm.size(); i++) {
    PVector s = cam.toScreen(swarm.get(i).pos.x, swarm.get(i).pos.y, swarm.get(i).pos.z);
    float d = dist(mouseX, mouseY, s.x, s.y);
    if (d < minDist) {
      minDist = d;
      closest = i;
    }
  }
  if (closest != selectedIndex) {
    selectedIndex = closest;
    Fly f = swarm.get(selectedIndex);
    logEvent("Selected Specimen #" + (selectedIndex + 1) + " (" + (f.isFemale ? "♀" : "♂") + ") for neural inspection.");
  }
}
