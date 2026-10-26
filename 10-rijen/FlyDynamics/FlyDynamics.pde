// =============================================================================
// FlyDynamics.pde - Diptera Neuro-Ethology & Biomechanics Laboratory
// =============================================================================
// Features:
// - Perfectly framed 3D Observation Cube (all 8 corners & ceiling fully visible)
// - Dedicated Bottom Panel: Pixel-art anatomical & biomechanical diagram of single fly
// - Spatial Working Memory & Central Complex Ring Attractor
// - Continuous ecosystem: Sustainable food replenishment, no flies freezing
// - Typography: Strict 8px Semplice Regular throughout (no font size changes)
// =============================================================================

Environment env;
ArrayList<Fly> swarm;
IsoCamera cam;
PFont pixelFont;

// Laboratory State & Controls
int selectedIndex = 0;
boolean macroFocusMode = false;
boolean simulationPaused = false;
int swarmInitialSize = 14;

// Circadian Photoperiod Cycle (Day / Night)
float dayNightTime = 0.25; // 0.0 to 1.0 (0.25 = noon, 0.75 = midnight)
boolean circadianAutoCycle = true;
color dayAmbient = color(14, 18, 26);
color nightAmbient = color(6, 8, 12);

// Real-time Ethology Laboratory Notebook (Event Log)
ArrayList<String> labLog = new ArrayList<String>();

void setup() {
  size(1360, 880);
  surface.setTitle("Diptera Ethology & Neuro-Biomechanics Laboratory (Processing 4)");
  frameRate(60);

  // Load Semplice Regular pixel font
  try {
    pixelFont = createFont("data/SempliceRegular.ttf", 8);
  } catch (Exception e) {
    try {
      pixelFont = createFont("Semplice Regular", 8);
    } catch (Exception e2) {
      pixelFont = createFont("Monospaced", 8);
    }
  }
  textFont(pixelFont, 8);

  // Camera calibrated so the ENTIRE 3D Cube (ground, pillars, ceiling, wire) is 100% visible
  cam = new IsoCamera(width / 2, 285, 0.44);
  env = new Environment();
  swarm = new ArrayList<Fly>();

  // Spawn initial cohort
  for (int i = 0; i < swarmInitialSize; i++) {
    float rx = random(-env.cubeW * 0.35, env.cubeW * 0.35);
    float ry = random(-env.cubeD * 0.35, env.cubeD * 0.35);
    float rz = (i % 3 == 0) ? 0 : random(30, env.cubeH * 0.75);
    Fly f = new Fly(rx, ry, rz);
    f.isFemale = (i % 2 == 0);
    f.bodyScale = f.isFemale ? 1.08 : 0.92;
    if (rz == 0) f.state = STATE_CRAWLING;
    swarm.add(f);
  }

  logEvent("LABORATORY READY: COHORT OF " + swarmInitialSize + " SPECIMENS.");
  logEvent("ECOSYSTEM: AUTONOMOUS SUCROSE & PROTEIN FORAGING ACTIVE.");
}

void draw() {
  textFont(pixelFont, 8);

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
      if (larva.isReadyToPupate()) {
        if (swarm.size() < 24) {
          Fly adult = new Fly(larva.pos.x, larva.pos.y, 0, larva.inheritedBrain);
          adult.state = STATE_CRAWLING;
          adult.trehalose = 0.95;
          swarm.add(adult);
          logEvent("ECLOSION: " + adult.brain.speciesName + " BORN (GEN F" + adult.brain.generation + ", INHERITED AERO " + int(adult.brain.inheritedAeroSkill * 100) + "%)");
        }
        env.larvae.remove(i);
      }
    }

    // Update all flies
    for (int i = 0; i < swarm.size(); i++) {
      Fly f = swarm.get(i);
      f.update(env, swarm);
      
      // Nighttime torpor on upper perch
      if (sunFactor < 0.15 && f.pos.z > env.cubeH * 0.7 && f.state == STATE_CRAWLING) {
        f.state = STATE_GROOMING;
      }
    }
  }

  // Camera tracking: Macro Mode vs Full-Cube Mode
  if (macroFocusMode && selectedIndex < swarm.size()) {
    Fly sel = swarm.get(selectedIndex);
    cam.targetZoom = 1.4;
    cam.targetOrigin.set(width/2 - sel.pos.x * 0.8, 285 - sel.pos.y * 0.4 + sel.pos.z * 0.6);
  } else {
    // Shows the full cube completely in camera without clipping any corners
    cam.targetZoom = 0.44;
    cam.targetOrigin.set(width / 2, 285);
  }
  cam.update();

  // 2. RENDER 3D TERRARIUM CUBE & ENTITIES
  env.displayCube(cam);

  // Render all flies in 3D world (few pixels avatars + flight trail)
  for (int i = 0; i < swarm.size(); i++) {
    Fly f = swarm.get(i);
    boolean isSelected = (i == selectedIndex);
    f.displayInWorld(cam, isSelected);
  }

  // 3. RENDER TOP HEADER & LAB NOTEBOOK
  displayHeaderBar(sunFactor);
  displayLabNotebook(18, 48, 260, 130);

  // 4. RENDER DEDICATED BOTTOM INSPECTOR (ALL FONTS EXACTLY SAME SIZE)
  if (selectedIndex >= swarm.size()) selectedIndex = max(0, swarm.size() - 1);
  Fly selFly = (swarm.size() > 0) ? swarm.get(selectedIndex) : null;
  if (selFly != null) {
    displayBottomInspector(selFly);
  }
}

// -----------------------------------------------------------------------------
// Dedicated Bottom Inspector Panel (Vision, Pixel-Art Fly Diagram, Brain HUD)
// -----------------------------------------------------------------------------
void displayBottomInspector(Fly f) {
  float bottomH = 265;
  float bottomY = height - bottomH - 8;
  float margin = 16;
  float totalW = width - margin * 2;

  float col1W = 280;
  float col2W = 570;
  float col3W = totalW - col1W - col2W - 20;

  float col1X = margin;
  float col2X = col1X + col1W + 10;
  float col3X = col2X + col2W + 10;

  // 1. LEFT: Compound Eye Low-Res Pixel Vision
  f.vision.displayHUD(col1X, bottomY, col1W, bottomH);

  // 2. CENTER: Pixel-Art Anatomical & Biomechanical Fly Diagram
  pushStyle();
  fill(10, 16, 26);
  stroke(55, 95, 140);
  strokeWeight(1);
  rect(col2X, bottomY, col2W, bottomH);

  // Title Banner & Specimen ID with Generation & Speciation Subspecies
  fill(190, 225, 255);
  textAlign(LEFT, TOP);
  String sexTitle = f.brain.speciesName + " #" + (selectedIndex + 1) + " (F" + f.brain.generation + " " + (f.isFemale ? "FEMALE" : "MALE") + ")";
  text(sexTitle, col2X + 10, bottomY + 8);

  // Thought stream badge
  fill(f.brain.thoughtColor, 40);
  stroke(f.brain.thoughtColor, 180);
  strokeWeight(1);
  rect(col2X + col2W - 250, bottomY + 6, 242, 14);
  fill(f.brain.thoughtColor);
  textAlign(CENTER, CENTER);
  text(f.brain.currentThought, col2X + col2W - 129, bottomY + 12);

  // Dedicated Simple Reasoning Layer Badge (Central Complex FB Deliberation)
  fill(16, 26, 40, 230);
  stroke(65, 125, 195, 180);
  strokeWeight(1);
  rect(col2X + 10, bottomY + 23, col2W - 20, 13);
  fill(160, 225, 255);
  textAlign(LEFT, CENTER);
  text("REASONING: " + f.brain.reasoningVerdict, col2X + 14, bottomY + 28);

  // Draw the Detailed Pixel-Art Fly Diagram (1:1 UNSCALED - Fonts match perfectly!)
  float diagramCenterX = col2X + 155;
  float diagramCenterY = bottomY + bottomH * 0.54;
  f.displayBottomDiagram(diagramCenterX, diagramCenterY);

  // Draw Specimen Bio-Status Meters (Right side inside column 2)
  float metersX = col2X + 320;
  float metersY = bottomY + 40;
  float metersW = col2W - 335;

  fill(170, 205, 240);
  textAlign(LEFT, TOP);
  text("STATE: " + getStateName(f.state) + " | STRAIN: " + f.brain.subspecies, metersX, metersY);
  metersY += 18;

  drawPixelBar("TREHALOSE FUEL", f.trehalose, color(255, 205, 50), metersX, metersY, metersW);
  metersY += 18;

  drawPixelBar("AIR NAV SKILL", f.brain.aeroSkill, color(90, 220, 255), metersX, metersY, metersW);
  metersY += 18;

  if (f.isFemale) {
    drawPixelBar("PROTEIN / EGGS", f.protein, color(235, 75, 140), metersX, metersY, metersW);
  } else {
    drawPixelBar("COURTSHIP URGE", f.brain.inputs[5], color(140, 110, 255), metersX, metersY, metersW);
  }
  metersY += 18;

  drawPixelBar("HYDRATION DEW", f.hydration, color(70, 210, 240), metersX, metersY, metersW);
  metersY += 18;

  drawPixelBar("SENSOR HYGIENE", f.cleanliness, color(80, 230, 130), metersX, metersY, metersW);
  metersY += 18;

  fill(150, 185, 220);
  text("TEMP: " + nf(f.bodyTemp, 0, 1) + " C | CRAB TRIM: " + nf(degrees(f.brain.crabAngle), 0, 1) + " DEG", metersX, metersY);
  metersY += 14;

  if (f.isFemale) {
    fill(255, 240, 180);
    text("OVIDUCT EGGS: " + f.matureEggs + " / 6 MATURE | F" + f.brain.generation, metersX, metersY);
  } else {
    fill(200, 180, 255);
    text("COURTSHIP SONG: 165 HZ | F" + f.brain.generation, metersX, metersY);
  }
  metersY += 14;

  fill(130, 180, 230);
  text("FOOD HITS: " + f.brain.foodFoundCount + "  |  REW: " + nf(f.brain.cumulativeReward, 0, 1), metersX, metersY);

  popStyle();

  // 3. RIGHT: Neuromorphic Micro-Brain & Learning Oscilloscope
  f.brain.displayLearningHUD(col3X, bottomY, col3W, bottomH);
}

// -----------------------------------------------------------------------------
// Top Header Bar & Lab Telemetry
// -----------------------------------------------------------------------------
void displayHeaderBar(float sunFactor) {
  pushStyle();
  fill(10, 15, 24);
  noStroke();
  rect(0, 0, width, 36);
  stroke(55, 95, 140);
  strokeWeight(1);
  line(0, 36, width, 36);

  fill(255);
  textAlign(LEFT, CENTER);
  text("DIPTERA ETHOLOGY & NEURO-BIOMECHANICS LABORATORY", 16, 18);

  int females = 0;
  int males = 0;
  int airborne = 0;
  for (Fly f : swarm) {
    if (f.isFemale) females++; else males++;
    if (f.state == STATE_FLYING || f.state == STATE_TAKEOFF) airborne++;
  }

  fill(130, 195, 255);
  String diurnalPhase = (sunFactor > 0.5) ? "DAY [12:00]" : (sunFactor > 0.1 ? "TWILIGHT" : "NIGHT (TORPOR)");
  text("POP:" + swarm.size() + " (F:" + females + " M:" + males + ") | EGGS:" + env.eggs.size() + " | LARVAE:" + env.larvae.size() + " | AIR:" + airborne + " | " + diurnalPhase, 390, 18);

  textAlign(RIGHT, CENTER);
  fill(175, 190, 210);
  text("[1]SUGAR [2]PROTEIN [3]DEW [W]WIND [D]DAY/NIGHT [F]THREAT [TAB]MACRO [P]PAUSE", width - 16, 18);
  popStyle();
}

// -----------------------------------------------------------------------------
// Real-Time Ethology Laboratory Notebook (Event Log)
// -----------------------------------------------------------------------------
void displayLabNotebook(float px, float py, float pw, float ph) {
  pushStyle();
  fill(10, 16, 26);
  stroke(50, 85, 130);
  strokeWeight(1);
  rect(px, py, pw, ph);

  fill(180, 220, 255);
  textAlign(LEFT, TOP);
  text("ETHOLOGY NOTEBOOK / EVENT LOG", px + 8, py + 6);

  float logY = py + 20;
  int startIdx = max(0, labLog.size() - 6);
  for (int i = startIdx; i < labLog.size(); i++) {
    fill(140, 180, 220);
    text(labLog.get(i), px + 8, logY);
    logY += 16;
  }
  popStyle();
}

void logEvent(String entry) {
  String timeStamp = nf(minute(), 2) + ":" + nf(second(), 2);
  labLog.add("[" + timeStamp + "] " + entry);
  if (labLog.size() > 40) labLog.remove(0);
}

void drawPixelBar(String label, float val, color col, float x, float y, float w) {
  fill(140, 175, 205);
  textAlign(LEFT, CENTER);
  text(label, x, y + 3);

  float barX = x + 95;
  float barW = w - 95;
  fill(20, 30, 42);
  noStroke();
  rect(barX, y, barW, 6);

  fill(col);
  rect(barX, y, barW * constrain(val, 0, 1), 6);
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
    PVector p = new PVector(random(-150, 150), random(-150, 150), 0);
    env.spawnFood(p, 0, "Sucrose Drop", 160);
    logEvent("DISPENSED SUCROSE DROPLET (CARB FUEL).");

  } else if (key == '2') {
    PVector p = new PVector(random(-150, 150), random(-150, 150), 0);
    env.spawnFood(p, 1, "Fermenting Yeast", 220);
    logEvent("DISPENSED YEAST (PROTEIN SUBSTRATE).");

  } else if (key == '3') {
    float gx = (random(1.0) > 0.5) ? env.cubeW * 0.48 : -env.cubeW * 0.48;
    env.poiList.add(new PointOfInterest(new PVector(gx, random(-100, 100), random(40, 160)), "Condensation Dew", color(80, 200, 255), 0));
    logEvent("MISTED GLASS WALL WITH DEW DROPS.");

  } else if (key == 'w' || key == 'W') {
    env.triggerGust(random(-2.5, 2.5), random(-2.5, 2.5));
    logEvent("WIND TUNNEL: CROSSWIND GUST TRIGGERED.");

  } else if (key == 'd' || key == 'D') {
    dayNightTime = (dayNightTime < 0.5) ? 0.75 : 0.25;
    logEvent("CIRCADIAN CYCLE: " + (dayNightTime > 0.5 ? "NIGHT" : "DAY"));

  } else if (key == 'f' || key == 'F') {
    env.threatActive = true;
    logEvent("GIANT FIBER TEST: LOOMING SHADOW CAST!");

  } else if (key == TAB) {
    macroFocusMode = !macroFocusMode;

  } else if (key == 'p' || key == 'P' || key == ' ') {
    simulationPaused = !simulationPaused;

  } else if (key == '+' || key == '=') {
    Fly f = new Fly(random(-100, 100), random(-100, 100), 20);
    swarm.add(f);

  } else if (key == '-' || key == '_') {
    if (swarm.size() > 1) swarm.remove(swarm.size() - 1);
  }
}

void mousePressed() {
  // If clicked inside the 3D cube area, check for fly selection
  if (mouseY < height - 280) {
    float minDist = 40;
    int closest = selectedIndex;
    for (int i = 0; i < swarm.size(); i++) {
      PVector s = cam.toScreen(swarm.get(i).pos.x, swarm.get(i).pos.y, swarm.get(i).pos.z);
      float d = dist(mouseX, mouseY, s.x, s.y);
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    if (closest != selectedIndex && closest < swarm.size()) {
      selectedIndex = closest;
      Fly f = swarm.get(selectedIndex);
      logEvent("SELECTED SPECIMEN #" + (selectedIndex + 1) + " (" + (f.isFemale ? "FEMALE" : "MALE") + ")");
    }
  }
}
