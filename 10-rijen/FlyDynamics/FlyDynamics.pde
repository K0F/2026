// =============================================================================
// FlyDynamics.pde - Diptera Neuro-Ethology & Biomechanics Laboratory
// =============================================================================
// An interactive laboratory for studying Diptera behavior, biomechanics, and cycles:
// - Zoomed-out 3D Observation Cube with tiny realistic fly avatars & flight trails
// - Dedicated Bottom Panel: Pixel-art anatomical & biomechanical diagram of single fly
// - Learning Curve & Mushroom Body Dopamine Oscilloscope
// - Dual bioenergetics: Trehalose flight fuel vs Protein oogenesis/vitellogenesis
// - Reproductive cycle: Courtship wing song -> Egg clutches -> Feeding larvae -> Adult eclosion
// - Circadian photoperiod cycle (Day/Night torpor)
// - Low-res compound eye ommatidia vision with looming optical flow detection
// - Typography: Semplice Regular pixel font throughout
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

  // Zoomed out camera to comfortably view the 3D Cube Terrarium in the upper area
  cam = new IsoCamera(width / 2, height * 0.32, 0.70);
  env = new Environment();
  swarm = new ArrayList<Fly>();

  // Spawn initial cohort
  for (int i = 0; i < swarmInitialSize; i++) {
    float rx = random(-env.cubeW * 0.38, env.cubeW * 0.38);
    float ry = random(-env.cubeD * 0.38, env.cubeD * 0.38);
    float rz = (i % 3 == 0) ? 0 : random(30, env.cubeH * 0.75);
    Fly f = new Fly(rx, ry, rz);
    f.isFemale = (i % 2 == 0);
    f.bodyScale = f.isFemale ? 1.08 : 0.92;
    if (rz == 0) f.state = STATE_CRAWLING;
    swarm.add(f);
  }

  logEvent("LABORATORY READY: COHORT OF " + swarmInitialSize + " SPECIMENS.");
  logEvent("CHAMBERS: SUCROSE DROP (CARBS), YEAST (PROTEIN), DEW.");
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
        if (swarm.size() < 28) {
          Fly adult = new Fly(larva.pos.x, larva.pos.y, 0, larva.inheritedBrain);
          adult.state = STATE_CRAWLING;
          adult.trehalose = 0.95;
          swarm.add(adult);
          logEvent("ECLOSION: LARVA PUPATED INTO ADULT " + (adult.isFemale ? "FEMALE" : "MALE") + " #" + swarm.size());
        }
        env.larvae.remove(i);
      }
    }

    // Update all flies
    for (int i = 0; i < swarm.size(); i++) {
      Fly f = swarm.get(i);
      f.update(env, swarm);
      
      // Nighttime torpor
      if (sunFactor < 0.15 && f.pos.z > env.cubeH * 0.65 && f.state == STATE_CRAWLING) {
        f.state = STATE_GROOMING;
      }
    }
  }

  // Camera tracking in Macro Focus Mode vs Normal Zoomed-Out Cube
  if (macroFocusMode && selectedIndex < swarm.size()) {
    Fly sel = swarm.get(selectedIndex);
    cam.targetZoom = 1.6;
    cam.targetOrigin.set(width/2 - sel.pos.x * 1.0, height * 0.32 - sel.pos.y * 0.5 + sel.pos.z * 0.7);
  } else {
    // Zoomed out cube comfortably framed in upper 60%
    cam.targetZoom = 0.70;
    cam.targetOrigin.set(width/2, height * 0.31);
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
  displayLabNotebook(18, 50, 260, 140);

  // 4. RENDER DEDICATED BOTTOM INSPECTOR (PIXEL ART FLY DIAGRAM, VISION & BRAIN)
  Fly selFly = (selectedIndex < swarm.size()) ? swarm.get(selectedIndex) : null;
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

  // Split into 3 columns:
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

  // Title Banner & Specimen ID
  fill(190, 225, 255);
  textAlign(LEFT, TOP);
  String sexTitle = f.isFemale ? "SPECIMEN #" + (selectedIndex + 1) + " (FEMALE DIPTERA)" : "SPECIMEN #" + (selectedIndex + 1) + " (MALE DIPTERA)";
  text(sexTitle, col2X + 10, bottomY + 8);

  // Thought stream badge
  fill(f.brain.thoughtColor, 40);
  stroke(f.brain.thoughtColor, 180);
  strokeWeight(1);
  rect(col2X + col2W - 220, bottomY + 6, 212, 14);
  fill(f.brain.thoughtColor);
  textAlign(CENTER, CENTER);
  text(f.brain.currentThought, col2X + col2W - 114, bottomY + 12);

  // Draw the Detailed Pixel-Art Fly Diagram
  float diagramCenterX = col2X + 155;
  float diagramCenterY = bottomY + bottomH * 0.54;
  f.displayBottomDiagram(diagramCenterX, diagramCenterY, 0.76);

  // Draw Specimen Bio-Status Meters (Right side inside column 2)
  float metersX = col2X + 320;
  float metersY = bottomY + 34;
  float metersW = col2W - 335;

  fill(170, 205, 240);
  textAlign(LEFT, TOP);
  text("STATE: " + getStateName(f.state), metersX, metersY);
  metersY += 18;

  drawPixelBar("TREHALOSE FUEL", f.trehalose, color(255, 205, 50), metersX, metersY, metersW);
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
  metersY += 20;

  fill(150, 185, 220);
  text("TEMP: " + nf(f.bodyTemp, 0, 1) + " C (" + int(f.wingFrequency) + " HZ WINGS)", metersX, metersY);
  metersY += 14;

  if (f.isFemale) {
    fill(255, 240, 180);
    text("OVIDUCT EGGS: " + f.matureEggs + " / 6 MATURE", metersX, metersY);
  } else {
    fill(200, 180, 255);
    text("COURTSHIP SONG: 165 HZ WING BUZZ", metersX, metersY);
  }
  metersY += 14;

  fill(130, 180, 230);
  text("FOOD HITS: " + f.brain.foodFoundCount + "  |  REW: " + nf(f.brain.cumulativeReward, 0, 1), metersX, metersY);

  popStyle();

  // 3. RIGHT: Neuromorphic Micro-Brain & Learning Oscilloscope
  f.brain.displayLearningHUD(col3X, bottomY, col3W, bottomH);
}

// -----------------------------------------------------------------------------
// Top Header Bar & Lab Telemetry (Pixel Art Aesthetic)
// -----------------------------------------------------------------------------
void displayHeaderBar(float sunFactor) {
  pushStyle();
  fill(10, 15, 24);
  noStroke();
  rect(0, 0, width, 38);
  stroke(55, 95, 140);
  strokeWeight(1);
  line(0, 38, width, 38);

  fill(255);
  textAlign(LEFT, CENTER);
  text("DIPTERA ETHOLOGY & NEURO-BIOMECHANICS LABORATORY", 16, 19);

  int females = 0;
  int males = 0;
  int airborne = 0;
  for (Fly f : swarm) {
    if (f.isFemale) females++; else males++;
    if (f.state == STATE_FLYING || f.state == STATE_TAKEOFF) airborne++;
  }

  fill(130, 195, 255);
  String diurnalPhase = (sunFactor > 0.5) ? "DAY [12:00]" : (sunFactor > 0.1 ? "TWILIGHT" : "NIGHT (TORPOR)");
  text("POP:" + swarm.size() + " (F:" + females + " M:" + males + ") | EGGS:" + env.eggs.size() + " | LARVAE:" + env.larvae.size() + " | AIR:" + airborne + " | " + diurnalPhase, 400, 19);

  textAlign(RIGHT, CENTER);
  fill(175, 190, 210);
  text("[1]SUGAR [2]PROTEIN [3]DEW [W]WIND [D]DAY/NIGHT [F]THREAT [TAB]MACRO [P]PAUSE", width - 16, 19);
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

  float logY = py + 22;
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

// Pixelated Progress Bar with Discrete Blocks
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
    env.spawnFood(p, FOOD_CARB, "Sucrose Drop", 160);
    logEvent("DISPENSED SUCROSE DROPLET (CARB FUEL).");

  } else if (key == '2') {
    PVector p = new PVector(random(-150, 150), random(-150, 150), 0);
    env.spawnFood(p, FOOD_PROTEIN, "Fermenting Yeast", 220);
    logEvent("DISPENSED YEAST (PROTEIN SUBSTRATE).");

  } else if (key == '3') {
    float gx = (random(1.0) > 0.5) ? env.cubeW * 0.48 : -env.cubeW * 0.48;
    env.poiList.add(new PointOfInterest(new PVector(gx, random(-100, 100), random(40, 160)), "Condensation Dew", color(80, 200, 255), POI_WATER));
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
  float minDist = 50;
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
    logEvent("SELECTED SPECIMEN #" + (selectedIndex + 1) + " (" + (f.isFemale ? "FEMALE" : "MALE") + ")");
  }
}
