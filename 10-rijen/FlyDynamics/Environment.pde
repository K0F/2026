// =============================================================================
// Environment.pde - 3D Terrarium Cube, Physics (Wind, Gravity), Food, Eggs & Larvae
// =============================================================================

// Food Types
final int FOOD_CARB = 0;    // Sugar, honey, nectar - trehalose energy for flight
final int FOOD_PROTEIN = 1; // Decaying organic matter, yeast - vitellogenesis & egg maturation

// Point of Interest Types
final int POI_WATER = 0;    // Moisture / condensation on glass
final int POI_WARM = 1;     // Warm perch wire / basking area
final int POI_GLASS = 2;    // Sunny vertical glass wall

class Environment {
  // Dimensions of the observation cube (mm scale representation)
  float cubeW = 640; // X axis
  float cubeD = 640; // Y axis
  float cubeH = 460; // Z axis (height / altitude)

  // Physical Gravity (pulls downward along Z)
  PVector gravity = new PVector(0, 0, -0.065);

  // Dynamic 3D Changing Wind Field
  PVector baseWind = new PVector(0, 0, 0);
  PVector windGust = new PVector(0, 0, 0);
  float windTime = 0;
  ArrayList<AirDriftParticle> airParticles;

  // Light source (ceiling mounted, generates heat and phototactic pull)
  PVector lightPos;
  float lightIntensity = 1.0;
  float lightPulse = 0;
  float lightThermalRadius = 160; // Warm zone around light

  // Food sources (Carbs & Protein)
  ArrayList<Food> foods;
  ArrayList<ScentParticle> scentTrail;

  // Points of Interest (Water, Warm perches, Glass walls)
  ArrayList<PointOfInterest> poiList;

  // Lifecycle: Eggs and Larvae
  ArrayList<Egg> eggs;
  ArrayList<Larva> larvae;

  // Predator / looming swat threat (3D position)
  PVector threatPos = new PVector(0, 0, 0);
  float threatSpeed = 0;
  PVector prevThreatPos = new PVector(0, 0, 0);
  float threatRadius = 140;
  boolean threatActive = false;
  float threatVisualRadius = 0;

  Environment() {
    // Light is mounted near the ceiling center
    lightPos = new PVector(0, -40, cubeH - 25);
    
    foods = new ArrayList<Food>();
    scentTrail = new ArrayList<ScentParticle>();
    poiList = new ArrayList<PointOfInterest>();
    eggs = new ArrayList<Egg>();
    larvae = new ArrayList<Larva>();
    airParticles = new ArrayList<AirDriftParticle>();

    // Initial atmospheric air drift motes (turbulent flow field visualizers)
    for (int i = 0; i < 140; i++) {
      airParticles.add(new AirDriftParticle(
        random(-cubeW * 0.45, cubeW * 0.45),
        random(-cubeD * 0.45, cubeD * 0.45),
        random(10, cubeH - 10)
      ));
    }

    // Points of interest:
    // 1. Water condensation droplets on glass wall (hydration)
    poiList.add(new PointOfInterest(new PVector(cubeW * 0.48, 40, 110), "Condensation Dew (Glass)", color(80, 200, 255), POI_WATER));
    poiList.add(new PointOfInterest(new PVector(-cubeW * 0.48, -60, 90), "Water Droplets (Glass)", color(80, 200, 255), POI_WATER));
    // 2. Warm ceiling perch wire (thermoregulation basking)
    poiList.add(new PointOfInterest(new PVector(0, 0, cubeH - 12), "Warm Ceiling Wire", color(255, 190, 80), POI_WARM));
    // 3. Sunny glass corner
    poiList.add(new PointOfInterest(new PVector(-cubeW * 0.44, cubeD * 0.44, 130), "Warm Glass Corner", color(255, 230, 140), POI_GLASS));

    // Initial Foods:
    // Sugar drop (Carbohydrate for instant flight fuel)
    spawnFood(new PVector(130, 120, 0), FOOD_CARB, "Sugar Syrup Drop", 160);
    // Decaying organic fruit (Protein substrate for female vitellogenesis & egg laying)
    spawnFood(new PVector(-140, -110, 0), FOOD_PROTEIN, "Fermenting Fruit (Protein)", 240);
  }

  void update() {
    // 1. Light flicker & heat emission
    lightPulse += 0.04;
    lightIntensity = 0.95 + 0.05 * sin(lightPulse);

    // 2. Dynamic Wind Calculation via Multi-Frequency 3D Perlin Noise
    windTime += 0.009;
    
    // Wind gust decay
    windGust.mult(0.95);

    // Update air drift particles in turbulent flow field
    for (AirDriftParticle p : airParticles) {
      PVector totalWind = getWindAt(p.pos);
      p.update(totalWind, cubeW, cubeD, cubeH);
    }

    // 3. Update Foods & Scent Emission
    float totalFoodAmount = 0;
    boolean hasCarb = false;
    boolean hasProtein = false;

    for (int i = foods.size() - 1; i >= 0; i--) {
      Food f = foods.get(i);
      f.update();
      if (f.amount <= 0) {
        foods.remove(i);
      } else {
        totalFoodAmount += f.amount;
        if (f.type == FOOD_CARB) hasCarb = true;
        if (f.type == FOOD_PROTEIN) hasProtein = true;

        if (frameCount % 6 == 0 && scentTrail.size() < 240) {
          // Emit olfactory plume particles carrying the odor
          color sCol = (f.type == FOOD_CARB) ? color(255, 220, 80) : color(220, 90, 160);
          scentTrail.add(new ScentParticle(
            f.pos.x + random(-8, 8),
            f.pos.y + random(-8, 8),
            f.pos.z + random(2, 8),
            sCol,
            f.type
          ));
        }
      }
    }

    // Sustainable Autonomous Food Replenishment: keeps multi-generational colony flourishing
    if ((!hasCarb || totalFoodAmount < 80) && frameCount % 450 == 0) {
      spawnFood(new PVector(random(-cubeW * 0.35, cubeW * 0.35), random(-cubeD * 0.35, cubeD * 0.35), 0), FOOD_CARB, "Sucrose Droplet", 180);
    }
    if ((!hasProtein || totalFoodAmount < 110) && (frameCount + 225) % 450 == 0) {
      spawnFood(new PVector(random(-cubeW * 0.35, cubeW * 0.35), random(-cubeD * 0.35, cubeD * 0.35), 0), FOOD_PROTEIN, "Fermenting Yeast", 220);
    }

    // Update scent particles with wind advection
    for (int i = scentTrail.size() - 1; i >= 0; i--) {
      ScentParticle sp = scentTrail.get(i);
      PVector w = getWindAt(sp.pos);
      sp.pos.add(PVector.mult(w, 0.7));
      sp.update();
      if (sp.life <= 0) {
        scentTrail.remove(i);
      }
    }

    // 4. Update Eggs and Larvae Lifecycle
    for (int i = eggs.size() - 1; i >= 0; i--) {
      Egg egg = eggs.get(i);
      egg.update();
      if (egg.isReadyToHatch()) {
        // Hatch into a mobile feeding larva (maggot)
        larvae.add(new Larva(egg.pos.x, egg.pos.y, egg.pos.z, egg.inheritedBrain));
        eggs.remove(i);
      }
    }

    for (int i = larvae.size() - 1; i >= 0; i--) {
      Larva larva = larvae.get(i);
      larva.update(this);
      // When larva reaches full development, it pupates & metamorphoses (handled in main loop)
    }

    // 5. Update Looming Threat (cursor / swatter)
    PVector currentThreat3D = unprojectMouseToGround(mouseX, mouseY);
    threatSpeed = PVector.dist(currentThreat3D, prevThreatPos);
    threatPos = currentThreat3D;
    prevThreatPos = currentThreat3D.copy();
    threatActive = (threatSpeed > 5.5 || mousePressed);
    threatVisualRadius = lerp(threatVisualRadius, threatActive ? threatRadius : 0, 0.2);
  }

  // Get total 3D wind vector at any coordinate (spatially varying turbulent flow field)
  PVector getWindAt(PVector p) {
    // Multi-frequency 3D Perlin noise flow field across space and time:
    // Scale 1: Macro terrarium circulation (wavelength ~380mm)
    float nx1 = p.x * 0.0026;
    float ny1 = p.y * 0.0026;
    float nz1 = p.z * 0.0030;

    // Scale 2: Meso turbulent convective vortices (wavelength ~110mm)
    float nx2 = p.x * 0.0090 + 17.3;
    float ny2 = p.y * 0.0090 + 29.1;
    float nz2 = p.z * 0.0110;

    // Scale 3: Micro turbulent boundary shear (wavelength ~32mm)
    float nx3 = p.x * 0.0310 + 73.5;
    float ny3 = p.y * 0.0310 + 84.2;
    float nz3 = p.z * 0.0310;

    float u = (noise(nx1, ny1, nz1 + windTime * 0.45) - 0.5) * 2.2
            + (noise(nx2, ny2, nz2 + windTime * 1.15) - 0.5) * 1.3
            + (noise(nx3, ny3, nz3 + windTime * 2.60) - 0.5) * 0.6;

    float v = (noise(nx1 + 37.1, ny1, nz1 + windTime * 0.45) - 0.5) * 2.2
            + (noise(nx2 + 37.1, ny2, nz2 + windTime * 1.15) - 0.5) * 1.3
            + (noise(nx3 + 37.1, ny3, nz3 + windTime * 2.60) - 0.5) * 0.6;

    float w = (noise(nx1 + 71.4, ny1 + 71.4, nz1 + windTime * 0.40) - 0.5) * 1.1
            + (noise(nx2 + 71.4, ny2 + 71.4, nz2 + windTime * 0.90) - 0.5) * 0.8;

    // Thermal convection chimney: air near the ceiling lamp heats and accelerates upwards
    float distToLamp = dist(p.x, p.y, lightPos.x, lightPos.y);
    if (distToLamp < lightThermalRadius && p.z > 25) {
      float thermalLift = map(distToLamp, 0, lightThermalRadius, 1.45, 0.0);
      w += thermalLift;

      // Air spreading outward radially under ceiling
      if (p.z > cubeH * 0.70) {
        float radDist = max(1.0, distToLamp);
        u += ((p.x - lightPos.x) / radDist) * 0.75;
        v += ((p.y - lightPos.y) / radDist) * 0.75;
      }
    }

    // Cool perimeter wall sinking drafts (convective loop closure)
    float edgeDistX = cubeW * 0.5 - abs(p.x);
    float edgeDistY = cubeD * 0.5 - abs(p.y);
    if ((edgeDistX < 55 || edgeDistY < 55) && p.z > 40) {
      w -= 0.55 * (1.0 - min(edgeDistX, edgeDistY) / 55.0);
    }

    PVector windVec = new PVector(u, v, w);
    windVec.add(windGust);
    return windVec;
  }

  void spawnFood(PVector pos, int type, String name, float amount) {
    foods.add(new Food(pos, type, name, amount));
  }

  void triggerGust(float powerX, float powerY) {
    windGust.set(powerX, powerY, random(-0.2, 0.5));
  }

  // ---------------------------------------------------------------------------
  // 3D Isometric Terrarium Cube Rendering
  // ---------------------------------------------------------------------------
  void displayCube(IsoCamera cam) {
    // Ground Floor Grid
    stroke(255, 18);
    strokeWeight(1);
    float step = 64;
    for (float x = -cubeW/2; x <= cubeW/2; x += step) {
      PVector p1 = cam.toScreen(x, -cubeD/2, 0);
      PVector p2 = cam.toScreen(x, cubeD/2, 0);
      line(p1.x, p1.y, p2.x, p2.y);
    }
    for (float y = -cubeD/2; y <= cubeD/2; y += step) {
      PVector p1 = cam.toScreen(-cubeW/2, y, 0);
      PVector p2 = cam.toScreen(cubeW/2, y, 0);
      line(p1.x, p1.y, p2.x, p2.y);
    }

    // Glass wall back planes (semi-translucent)
    noStroke();
    fill(18, 30, 48, 35);
    // Back-left wall (-X)
    beginShape();
    PVector v1 = cam.toScreen(-cubeW/2, -cubeD/2, 0);
    PVector v2 = cam.toScreen(-cubeW/2, cubeD/2, 0);
    PVector v3 = cam.toScreen(-cubeW/2, cubeD/2, cubeH);
    PVector v4 = cam.toScreen(-cubeW/2, -cubeD/2, cubeH);
    vertex(v1.x, v1.y); vertex(v2.x, v2.y); vertex(v3.x, v3.y); vertex(v4.x, v4.y);
    endShape(CLOSE);

    // Back-right wall (-Y)
    fill(18, 30, 48, 25);
    beginShape();
    v1 = cam.toScreen(-cubeW/2, -cubeD/2, 0);
    v2 = cam.toScreen(cubeW/2, -cubeD/2, 0);
    v3 = cam.toScreen(cubeW/2, -cubeD/2, cubeH);
    v4 = cam.toScreen(-cubeW/2, -cubeD/2, cubeH);
    vertex(v1.x, v1.y); vertex(v2.x, v2.y); vertex(v3.x, v3.y); vertex(v4.x, v4.y);
    endShape(CLOSE);

    // Cube Frame Edges
    stroke(70, 130, 195, 75);
    strokeWeight(1.5);
    // Base edges
    drawEdge(cam, -cubeW/2, -cubeD/2, 0,  cubeW/2, -cubeD/2, 0);
    drawEdge(cam,  cubeW/2, -cubeD/2, 0,  cubeW/2,  cubeD/2, 0);
    drawEdge(cam,  cubeW/2,  cubeD/2, 0, -cubeW/2,  cubeD/2, 0);
    drawEdge(cam, -cubeW/2,  cubeD/2, 0, -cubeW/2, -cubeD/2, 0);

    // Vertical Pillars
    stroke(70, 130, 195, 55);
    drawEdge(cam, -cubeW/2, -cubeD/2, 0, -cubeW/2, -cubeD/2, cubeH);
    drawEdge(cam,  cubeW/2, -cubeD/2, 0,  cubeW/2, -cubeD/2, cubeH);
    drawEdge(cam,  cubeW/2,  cubeD/2, 0,  cubeW/2,  cubeD/2, cubeH);
    drawEdge(cam, -cubeW/2,  cubeD/2, 0, -cubeW/2,  cubeD/2, cubeH);

    // Ceiling Edges & Perch Wire
    stroke(110, 175, 245, 85);
    drawEdge(cam, -cubeW/2, -cubeD/2, cubeH,  cubeW/2, -cubeD/2, cubeH);
    drawEdge(cam,  cubeW/2, -cubeD/2, cubeH,  cubeW/2,  cubeD/2, cubeH);
    drawEdge(cam,  cubeW/2,  cubeD/2, cubeH, -cubeW/2,  cubeD/2, cubeH);
    drawEdge(cam, -cubeW/2,  cubeD/2, cubeH, -cubeW/2, -cubeD/2, cubeH);

    // Warm Perch Wire crossing top
    stroke(255, 190, 80, 140);
    strokeWeight(2.0);
    drawEdge(cam, -cubeW * 0.45, 0, cubeH - 12, cubeW * 0.45, 0, cubeH - 12);

    // Draw Light Source (Ceiling bulb + radiant glow)
    PVector sLight = cam.toScreen(lightPos.x, lightPos.y, lightPos.z);
    noStroke();
    fill(255, 245, 170, 40 * lightIntensity);
    ellipse(sLight.x, sLight.y, 65, 65);
    fill(255, 250, 200, 180 * lightIntensity);
    ellipse(sLight.x, sLight.y, 22, 22);
    fill(255, 255, 255);
    ellipse(sLight.x, sLight.y, 10, 10);

    // Thermal updraft visual indicator above light
    stroke(255, 210, 100, 35);
    strokeWeight(1);
    for (int k = 0; k < 3; k++) {
      float offX = sin(frameCount * 0.05 + k) * 12;
      float lz = lightPos.z - 40 - k * 25;
      PVector t1 = cam.toScreen(lightPos.x + offX, lightPos.y, lz);
      PVector t2 = cam.toScreen(lightPos.x + offX, lightPos.y, lz + 20);
      line(t1.x, t1.y, t2.x, t2.y);
    }

    // Render Air Drift Streamlines (Visualizing dynamic 3D turbulent flow field)
    strokeWeight(1.0);
    for (AirDriftParticle ap : airParticles) {
      PVector sp1 = cam.toScreen(ap.prevPos.x, ap.prevPos.y, ap.prevPos.z);
      PVector sp2 = cam.toScreen(ap.pos.x, ap.pos.y, ap.pos.z);
      stroke(130, 205, 255, ap.alpha);
      line(sp1.x, sp1.y, sp2.x, sp2.y);
      stroke(200, 240, 255, ap.alpha * 0.8);
      point(sp2.x, sp2.y);
    }

    // Render Scent Trail Particles
    noStroke();
    for (ScentParticle sp : scentTrail) {
      PVector sPos = cam.toScreen(sp.pos.x, sp.pos.y, sp.pos.z);
      fill(sp.col, sp.alpha);
      ellipse(sPos.x, sPos.y, sp.radius, sp.radius);
    }

    // Render Points of Interest
    for (PointOfInterest poi : poiList) {
      poi.display(cam);
    }

    // Render Food Sources
    for (Food f : foods) {
      f.display(cam);
    }

    // Render Eggs
    for (Egg egg : eggs) {
      egg.display(cam);
    }

    // Render Larvae (Maggots)
    for (Larva larva : larvae) {
      larva.display(cam);
    }

    // Render Looming Swat Shadow / Threat
    if (threatVisualRadius > 2.0) {
      PVector sThreat = cam.toScreen(threatPos.x, threatPos.y, 0);
      fill(255, 40, 40, 30);
      stroke(255, 60, 60, 140);
      strokeWeight(1.5);
      ellipse(sThreat.x, sThreat.y, threatVisualRadius * 1.8, threatVisualRadius * 1.0);
      fill(255, 60, 60);
      textAlign(CENTER, CENTER);
      text("! LOOMING SWATER SHADOW !", sThreat.x, sThreat.y - 18);
    }
  }

  void drawEdge(IsoCamera cam, float x1, float y1, float z1, float x2, float y2, float z2) {
    PVector p1 = cam.toScreen(x1, y1, z1);
    PVector p2 = cam.toScreen(x2, y2, z2);
    line(p1.x, p1.y, p2.x, p2.y);
  }

  PVector unprojectMouseToGround(float mx, float my) {
    float dx = mx - width / 2;
    float dy = my - (height / 2 - 20);
    float cosA = cos(PI/6);
    float sinA = sin(PI/6);
    float x = (dx / cosA + dy / sinA) * 0.5;
    float y = (dy / sinA - dx / cosA) * 0.5;
    return new PVector(constrain(x, -cubeW/2, cubeW/2), constrain(y, -cubeD/2, cubeD/2), 0);
  }
}

// -----------------------------------------------------------------------------
// Food Entity: Carbohydrate (Flight Sugar) vs Protein (Egg Vitellogenesis)
// -----------------------------------------------------------------------------
class Food {
  PVector pos;
  int type; // FOOD_CARB or FOOD_PROTEIN
  String name;
  float amount;
  float maxAmount;
  color baseColor;

  Food(PVector pos, int type, String name, float amount) {
    this.pos = pos.copy();
    this.type = type;
    this.name = name;
    this.amount = amount;
    this.maxAmount = amount;
    this.baseColor = (type == FOOD_CARB) ? color(255, 205, 50) : color(225, 75, 120);
  }

  void update() {
    // Decaying / evaporation over very long time
    amount -= 0.003;
  }

  void consume(float delta) {
    amount = max(0, amount - delta);
  }

  void display(IsoCamera cam) {
    PVector s = cam.toScreen(pos.x, pos.y, pos.z);
    float r = map(amount, 0, maxAmount, 6, 22);

    pushStyle();
    // Drop shadow
    noStroke();
    fill(0, 70);
    ellipse(s.x + 2, s.y + 2, r * 1.5, r * 0.8);

    // Food mass
    fill(baseColor, 220);
    stroke(baseColor);
    strokeWeight(1.2);
    ellipse(s.x, s.y, r * 1.4, r * 0.9);

    // Inner nutrient highlight
    fill(255, 180);
    noStroke();
    ellipse(s.x - r * 0.25, s.y - r * 0.2, r * 0.4, r * 0.25);

    // Label & Nutrition badge
    fill(230, 240, 255);
    textAlign(CENTER, BOTTOM);
    String typeTag = (type == FOOD_CARB) ? "[CARB]" : "[PROTEIN]";
    text(name + " " + typeTag, s.x, s.y - r * 0.6 - 4);
    popStyle();
  }
}

// -----------------------------------------------------------------------------
// Point of Interest: Moisture / Dew, Warm Perches, Sunny Glass
// -----------------------------------------------------------------------------
class PointOfInterest {
  PVector pos;
  String name;
  color col;
  int type;

  PointOfInterest(PVector pos, String name, color col, int type) {
    this.pos = pos.copy();
    this.name = name;
    this.col = col;
    this.type = type;
  }

  void display(IsoCamera cam) {
    PVector s = cam.toScreen(pos.x, pos.y, pos.z);
    pushStyle();
    if (type == POI_WATER) {
      // Condensation dew drops
      noStroke();
      fill(100, 210, 255, 160);
      ellipse(s.x, s.y, 10, 10);
      ellipse(s.x + 8, s.y - 5, 7, 7);
      ellipse(s.x - 6, s.y + 4, 6, 6);
      fill(255, 230);
      ellipse(s.x - 2, s.y - 2, 3, 3);
    } else {
      // Warm marker
      stroke(col, 160);
      strokeWeight(1);
      noFill();
      ellipse(s.x, s.y, 14, 14);
      fill(col);
      ellipse(s.x, s.y, 4, 4);
    }

    fill(col, 200);
    textAlign(CENTER, TOP);
    text(name, s.x, s.y + 9);
    popStyle();
  }
}

// -----------------------------------------------------------------------------
// Atmospheric Drift Particle (Visualizing dynamic 3D wind & thermal currents)
// -----------------------------------------------------------------------------
class AirDriftParticle {
  PVector pos;
  PVector prevPos;
  float alpha;

  AirDriftParticle(float x, float y, float z) {
    pos = new PVector(x, y, z);
    prevPos = pos.copy();
    alpha = random(40, 115);
  }

  void update(PVector wind, float w, float d, float h) {
    prevPos.set(pos);
    pos.add(wind);
    // Boundary wrap
    boolean wrapped = false;
    if (pos.x > w/2) { pos.x = -w/2; wrapped = true; }
    if (pos.x < -w/2) { pos.x = w/2; wrapped = true; }
    if (pos.y > d/2) { pos.y = -d/2; wrapped = true; }
    if (pos.y < -d/2) { pos.y = d/2; wrapped = true; }
    if (pos.z > h) { pos.z = 2; wrapped = true; }
    if (pos.z < 0) { pos.z = h - 2; wrapped = true; }
    if (wrapped) prevPos.set(pos);
  }
}

// -----------------------------------------------------------------------------
// Scent / Olfactory Particle
// -----------------------------------------------------------------------------
class ScentParticle {
  PVector pos;
  color col;
  int foodType;
  float life = 1.0;
  float radius = 3.5;
  float alpha = 140;

  ScentParticle(float x, float y, float z, color c, int type) {
    pos = new PVector(x, y, z);
    col = c;
    foodType = type;
  }

  void update() {
    pos.z += 0.25; // Odor wafts upward
    life -= 0.012;
    alpha = life * 130;
    radius += 0.06;
  }
}

// -----------------------------------------------------------------------------
// Egg Entity (Dipteran Ovum)
// -----------------------------------------------------------------------------
class Egg {
  PVector pos;
  float incubation = 0.0; // 0.0 to 1.0
  float hatchRate = 0.0018; // Incubation speed
  FlyBrain inheritedBrain;

  Egg(float x, float y, float z, FlyBrain brain) {
    pos = new PVector(x, y, z);
    inheritedBrain = brain.mutateCopy();
  }

  void update() {
    incubation += hatchRate;
  }

  boolean isReadyToHatch() {
    return incubation >= 1.0;
  }

  void display(IsoCamera cam) {
    PVector s = cam.toScreen(pos.x, pos.y, pos.z);
    pushStyle();
    // Creamy white elongated dipteran egg with micropyle
    fill(245, 240, 220, 230);
    stroke(180, 175, 150);
    strokeWeight(0.8);
    ellipse(s.x, s.y, 7, 3.5);
    popStyle();
  }
}

// -----------------------------------------------------------------------------
// Larva Entity (Dipteran Maggot: Feeds on Protein, Pupates)
// -----------------------------------------------------------------------------
class Larva {
  PVector pos;
  PVector vel;
  float growth = 0.0; // 0.0 to 1.0
  float peristalsisPhase = 0;
  FlyBrain inheritedBrain;

  Larva(float x, float y, float z, FlyBrain brain) {
    pos = new PVector(x, y, z);
    vel = new PVector(random(-0.3, 0.3), random(-0.3, 0.3), 0);
    inheritedBrain = brain;
  }

  void update(Environment env) {
    peristalsisPhase += 0.15;
    growth += 0.0016;

    // Larva crawls toward nearby food to feed
    Food nearest = null;
    float minDist = 999;
    for (Food f : env.foods) {
      float d = PVector.dist(pos, f.pos);
      if (d < minDist) {
        minDist = d;
        nearest = f;
      }
    }

    if (nearest != null && minDist > 6) {
      PVector dir = PVector.sub(nearest.pos, pos);
      dir.z = 0;
      dir.normalize();
      dir.mult(0.35 * (1.0 + sin(peristalsisPhase) * 0.5));
      pos.add(dir);
    } else if (nearest != null) {
      nearest.consume(0.04);
      growth += 0.002; // Feeding accelerates pupation
    }
  }

  boolean isReadyToPupate() {
    return growth >= 1.0;
  }

  void display(IsoCamera cam) {
    PVector s = cam.toScreen(pos.x, pos.y, pos.z);
    pushStyle();
    // Segmented maggot body with peristaltic wave
    float len = map(growth, 0, 1, 8, 14);
    noStroke();
    fill(235, 230, 205, 210);
    ellipse(s.x, s.y, len, 4 + sin(peristalsisPhase) * 1.5);
    // Dark cephalopharyngeal mouth hook
    fill(40, 30, 20);
    ellipse(s.x + len * 0.4, s.y, 2, 2);
    popStyle();
  }
}

// -----------------------------------------------------------------------------
// Isometric 3D Projection Camera
// -----------------------------------------------------------------------------
class IsoCamera {
  PVector origin;
  PVector targetOrigin;
  float zoom = 1.0;
  float targetZoom = 1.0;
  float angle = PI / 6; // 30-degree isometric tilt

  IsoCamera(float ox, float oy, float z) {
    origin = new PVector(ox, oy);
    targetOrigin = new PVector(ox, oy);
    zoom = z;
    targetZoom = z;
  }

  void update() {
    origin.x = lerp(origin.x, targetOrigin.x, 0.1);
    origin.y = lerp(origin.y, targetOrigin.y, 0.1);
    zoom = lerp(zoom, targetZoom, 0.1);
  }

  PVector toScreen(float x, float y, float z) {
    float isoX = (x - y) * cos(angle);
    float isoY = (x + y) * sin(angle) - z;
    return new PVector(origin.x + isoX * zoom, origin.y + isoY * zoom);
  }
}
