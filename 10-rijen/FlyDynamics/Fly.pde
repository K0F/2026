// =============================================================================
// Fly.pde - Dipteran Biomechanics, Sexual Dimorphism, Metabolism & Lifecycle
// =============================================================================

// Behavioral States
final int STATE_FLYING = 0;
final int STATE_TAKEOFF = 1;
final int STATE_LANDING = 2;
final int STATE_CRAWLING = 3;
final int STATE_FEEDING = 4;
final int STATE_GROOMING = 5;
final int STATE_COURTSHIP = 6;

class Fly {
  // 3D Spatial kinematics
  PVector pos;
  PVector vel;
  PVector acc;
  float heading = 0; // Yaw angle (horizontal)
  float pitch = 0;   // Vertical angle
  float roll = 0;    // Banking roll angle

  // Sexual Dimorphism
  boolean isFemale = true;
  float bodyScale = 1.0;
  float abdomenScale = 1.0;
  
  // Oviposition & Vitellogenesis (Females)
  float vitellogenesis = 0.0; // Protein conversion into mature eggs (0.0 to 1.0)
  int matureEggs = 0;
  float ovipositorExtension = 0; // 0 = retracted, 1 = extended
  
  // Courtship display (Males)
  float courtshipWingAngle = 0; // Unilateral wing vibration angle (90 deg)
  float courtshipBuzzPhase = 0;
  Fly targetMate = null;

  // Behavior state machine
  int state = STATE_FLYING;
  float stateTimer = 0;

  // Biomechanics: Wings & Halteres
  float wingFold = 1.0;          // 0.0 = folded flat on abdomen, 1.0 = deployed
  float wingPhase = 0;           // High-frequency flapping phase
  float wingFrequency = 180.0;   // In Hz (140 - 220 Hz depending on temperature)
  float halterePhase = 0;        // Oscillating anti-phase to wings

  // Biomechanics: 6 Legs with Alternating Tripod Gait
  // Index: 0=L1(Front), 1=R1(Front), 2=L2(Mid), 3=R2(Mid), 4=L3(Hind), 5=R3(Hind)
  PVector[] legBases = new PVector[6];
  PVector[] legTips = new PVector[6];
  float tripodPhase = 0;
  int groomType = 0; // 0 = Head/Eyes, 1 = Wings/Abdomen
  float groomPhase = 0;

  // Bioenergetics & Homeostasis
  float trehalose = 0.85;  // Carbohydrate flight fuel (0.0 to 1.0)
  float protein = 0.2;     // Protein store for eggs/larval nutrition
  float hydration = 0.9;   // Water balance (desiccation risk)
  float cleanliness = 0.95;// Sensor & tarsal pulvilli cleanliness (0.0 to 1.0)
  float bodyTemp = 24.0;   // Body temperature in Celsius (ectotherm)

  // Neuromorphic Brain & Vision
  FlyBrain brain;
  FlyVision vision;

  // Proboscis feeding apparatus
  float proboscisExtend = 0;
  float respirationPulse = 0;

  // Surface attachment normal (1 = Floor, -1 = Ceiling, 2/-2 = Walls)
  int surfaceAttachment = 1; 

  Fly(float x, float y, float z) {
    pos = new PVector(x, y, z);
    vel = new PVector(random(-1, 1), random(-1, 1), random(-0.5, 0.5));
    acc = new PVector(0, 0, 0);
    heading = random(TWO_PI);
    
    // Sex assignment: 50% Female, 50% Male
    isFemale = (random(1.0) > 0.5);
    bodyScale = isFemale ? 1.05 : 0.92;
    abdomenScale = isFemale ? 1.15 : 0.85;

    brain = new FlyBrain();
    vision = new FlyVision();

    initLegs();
  }

  Fly(float x, float y, float z, FlyBrain inheritedBrain) {
    this(x, y, z);
    this.brain = inheritedBrain.mutateCopy();
  }

  void initLegs() {
    for (int i = 0; i < 6; i++) {
      legBases[i] = new PVector();
      legTips[i] = new PVector();
    }
    updateLegPositions(true);
  }

  void update(Environment env, ArrayList<Fly> swarm) {
    respirationPulse += 0.08;

    // 1. THERMOREGULATION & METABOLISM
    // Ambient temperature: warmer near the lamp (ceiling light)
    float distToLight = PVector.dist(pos, env.lightPos);
    float targetTemp = map(constrain(distToLight, 30, 450), 30, 450, 32.0, 20.0);
    bodyTemp = lerp(bodyTemp, targetTemp, 0.02);
    // Wing beat frequency depends on thoracic temperature!
    wingFrequency = map(bodyTemp, 20.0, 32.0, 140.0, 220.0);

    // Energy consumption:
    // Flight burns trehalose at extreme rates!
    if (state == STATE_FLYING) {
      trehalose = max(0, trehalose - 0.00075);
      hydration = max(0, hydration - 0.00025);
    } else if (state == STATE_CRAWLING) {
      trehalose = max(0, trehalose - 0.00015);
      hydration = max(0, hydration - 0.00010);
    } else {
      // Basal resting metabolism
      trehalose = max(0, trehalose - 0.00005);
    }

    // Dust accumulates over time, impairing vision and tarsal adhesion
    cleanliness = max(0.1, cleanliness - 0.00018);

    // Vitellogenesis: in females, protein is processed into mature egg clutches
    if (isFemale && protein > 0.35 && matureEggs < 6) {
      vitellogenesis += 0.0012;
      if (vitellogenesis >= 1.0) {
        matureEggs++;
        protein = max(0, protein - 0.25);
        vitellogenesis = 0;
      }
    }

    // 2. SENSORY INFLUX GATHERING
    float carbOdor = 0;
    float proteinOdor = 0;
    Food closestFood = null;
    float minDist = 9999;

    for (Food f : env.foods) {
      float d = PVector.dist(pos, f.pos);
      if (d < minDist) {
        minDist = d;
        closestFood = f;
      }
      float odorIntensity = max(0, 1.0 - d / 320.0);
      if (f.type == FOOD_CARB) carbOdor += odorIntensity;
      else proteinOdor += odorIntensity;
    }

    // Tarsal sugar taste: when landed directly on sugar food
    float tarsalSugar = 0;
    if (closestFood != null && minDist < 24 && closestFood.type == FOOD_CARB && state != STATE_FLYING) {
      tarsalSugar = 1.0;
    }

    // Sun / Light Compass bearing (Central Complex input)
    PVector diffLight = PVector.sub(env.lightPos, pos);
    float angleToLight = atan2(diffLight.y, diffLight.x) - heading;
    while (angleToLight > PI) angleToLight -= TWO_PI;
    while (angleToLight < -PI) angleToLight += TWO_PI;
    float compassBearing = constrain(angleToLight / PI, -1, 1);

    // Pheromone sensing & mate tracking
    float pheromoneSignal = 0;
    targetMate = null;
    float minMateDist = 999;
    for (Fly other : swarm) {
      if (other != this && other.isFemale != this.isFemale) {
        float d = PVector.dist(pos, other.pos);
        if (d < 220) {
          pheromoneSignal += (1.0 - d / 220.0);
          if (d < minMateDist) {
            minMateDist = d;
            targetMate = other;
          }
        }
      }
    }

    // Haltere Coriolis gyro metric: measures angular roll/yaw rate
    float haltereGyro = abs(vel.x * sin(heading) - vel.y * cos(heading)) * 0.1;

    // Update Compound Eye Vision
    vision.update(pos, heading, pitch, env, swarm, this);

    // 3. BRAIN REASONING COMPUTATION
    brain.compute(
      vision.getLeftLuminance(),
      vision.getRightLuminance(),
      vision.loomingFactor,
      carbOdor,
      proteinOdor,
      pheromoneSignal,
      tarsalSugar,
      haltereGyro,
      compassBearing,
      1.0 - trehalose, // Trehalose hunger
      isFemale ? (1.0 - protein) : (targetMate != null ? 0.8 : 0.1), // Protein urge / Mating drive
      1.0 - hydration  // Thirst
    );

    // 4. MOTOR ACTUATION & STATE MACHINE
    float wingThrustCmd = brain.outputs[0];
    float steerCmd = (brain.outputs[1] - 0.5) * 2.0;
    float pitchCmd = (brain.outputs[2] - 0.5) * 2.0;
    float jumpCmd = brain.outputs[3];
    float gaitCmd = brain.outputs[4];
    float feedCmd = brain.outputs[5];
    float ovipositWingCmd = brain.outputs[6];

    // State Machine Decision Logic
    handleStateMachine(env, jumpCmd, feedCmd, ovipositWingCmd, closestFood, minDist);

    // 5. KINEMATIC INTEGRATION
    PVector wind = env.getWindAt(pos);

    if (state == STATE_FLYING) {
      // Wings deployed & oscillating at biological frequency
      wingFold = min(1.0, wingFold + 0.15);
      wingPhase += (wingFrequency / 60.0) * TWO_PI * 0.08;
      halterePhase += (wingFrequency / 60.0) * TWO_PI * 0.08;

      // Exhaustion stall if trehalose is zero!
      if (trehalose <= 0.01) {
        wingThrustCmd *= 0.2; // Power failure!
      }

      // Aerodynamic Steering
      heading += steerCmd * 0.11;
      pitch = lerp(pitch, pitchCmd * 0.45, 0.1);
      roll = lerp(roll, -steerCmd * 0.55, 0.12);

      // Forward Thrust Vector
      PVector thrust = new PVector(cos(heading) * cos(pitch), sin(heading) * cos(pitch), sin(pitch));
      thrust.mult(wingThrustCmd * 2.4);
      acc.add(thrust);

      // Physical Gravity & Dynamic Wind
      acc.add(env.gravity);
      acc.add(PVector.mult(wind, 0.12));

      // Aerodynamic Damping
      vel.add(acc);
      vel.mult(0.93);
      pos.add(vel);
      acc.set(0, 0, 0);

      // Tuck legs in aerodynamically
      updateLegPositions(false);

    } else if (state == STATE_TAKEOFF) {
      // Mesothoracic Jump (TTM muscle catapult) + instant wing deploy!
      wingFold = min(1.0, wingFold + 0.25);
      wingPhase += 0.8;
      pos.z += 4.0;
      vel.z = 2.4;
      stateTimer += 0.12;
      if (stateTimer > 0.8 || pos.z > 16) {
        state = STATE_FLYING;
      }

    } else if (state == STATE_LANDING) {
      // Decelerate, swing legs out for tarsal contact, fold wings
      vel.mult(0.65);
      pos.z = max(0, pos.z - 2.2);
      wingFold = max(0.0, wingFold - 0.1);
      pitch = lerp(pitch, -0.2, 0.1);

      if (pos.z <= 0.5) {
        pos.z = 0;
        vel.set(0, 0, 0);
        state = STATE_CRAWLING;
        wingFold = 0.0; // Folded flat over abdomen
      }
      updateLegPositions(true);

    } else if (state == STATE_CRAWLING) {
      wingFold = max(0.0, wingFold - 0.12);
      pos.z = 0;

      // Hexapod Alternating Tripod Gait
      float crawlSpeed = gaitCmd * 1.6;
      heading += steerCmd * 0.06;
      pos.x += cos(heading) * crawlSpeed;
      pos.y += sin(heading) * crawlSpeed;
      tripodPhase += crawlSpeed * 0.45;

      updateLegPositions(true);

    } else if (state == STATE_FEEDING) {
      pos.z = 0;
      wingFold = 0.0;
      proboscisExtend = lerp(proboscisExtend, 1.0, 0.15);

      // Ingest nutrients & reward dopamine
      if (closestFood != null && minDist < 24) {
        if (closestFood.type == FOOD_CARB) {
          closestFood.consume(0.14);
          trehalose = min(1.0, trehalose + 0.0035);
          brain.applyDopamineReward(0.8);
        } else {
          closestFood.consume(0.12);
          protein = min(1.0, protein + 0.003);
          brain.applyDopamineReward(0.7);
        }
      }
      updateLegPositions(true);

    } else if (state == STATE_GROOMING) {
      pos.z = 0;
      wingFold = 0.0;
      groomPhase += 0.22;
      cleanliness = min(1.0, cleanliness + 0.003); // Restores sensory cleanliness!

      if (cleanliness >= 0.98) {
        state = STATE_CRAWLING;
      }
      updateLegPositions(true);

    } else if (state == STATE_COURTSHIP) {
      pos.z = 0;
      if (!isFemale) {
        // Male: Unilateral wing extension & acoustic courtship song!
        courtshipWingAngle = lerp(courtshipWingAngle, HALF_PI * 0.85, 0.1);
        courtshipBuzzPhase += 0.5;
        // Turn toward female
        if (targetMate != null) {
          PVector d = PVector.sub(targetMate.pos, pos);
          heading = lerp(heading, atan2(d.y, d.x), 0.1);
          if (PVector.dist(pos, targetMate.pos) < 18) {
            // Copulation attempt!
            targetMate.brain.applyDopamineReward(1.0);
            this.brain.applyDopamineReward(1.0);
            state = STATE_CRAWLING;
          }
        }
      } else {
        // Female: if mature eggs ready and near protein food, extend ovipositor and lay eggs!
        if (matureEggs > 0 && closestFood != null && minDist < 35 && closestFood.type == FOOD_PROTEIN) {
          ovipositorExtension = lerp(ovipositorExtension, 1.0, 0.15);
          if (ovipositorExtension > 0.85 && frameCount % 35 == 0) {
            // Deposit egg clutch on protein substrate
            env.eggs.add(new Egg(pos.x + random(-4, 4), pos.y + random(-4, 4), 0, this.brain));
            matureEggs--;
            brain.applyDopamineReward(1.0); // High biological satisfaction!
            if (matureEggs <= 0) {
              ovipositorExtension = 0;
              state = STATE_CRAWLING;
            }
          }
        }
      }
      updateLegPositions(true);
    }

    // Hydration replenishment near water POI
    for (PointOfInterest poi : env.poiList) {
      if (poi.type == POI_WATER && PVector.dist(pos, poi.pos) < 25) {
        hydration = min(1.0, hydration + 0.004);
        brain.applyDopamineReward(0.5);
      }
    }

    // Contain inside Terrarium Cube
    keepInCube(env);
  }

  void handleStateMachine(Environment env, float jumpCmd, float feedCmd, float ovipositWingCmd, Food closestFood, float minDist) {
    // 1. Giant Fiber Escape Reflex overrides EVERYTHING!
    if (vision.loomingFactor > 0.35 && state != STATE_FLYING && state != STATE_TAKEOFF) {
      state = STATE_TAKEOFF;
      stateTimer = 0;
      return;
    }

    // 2. Takeoff Trigger
    if (jumpCmd > 0.75 && (state == STATE_CRAWLING || state == STATE_GROOMING) && trehalose > 0.05) {
      state = STATE_TAKEOFF;
      stateTimer = 0;
      return;
    }

    // 3. Landing Trigger
    if (state == STATE_FLYING && (trehalose < 0.15 || (closestFood != null && minDist < 45 && pos.z < 60))) {
      state = STATE_LANDING;
      return;
    }

    // 4. Feeding Trigger on Ground
    if (state == STATE_CRAWLING && closestFood != null && minDist < 24 && feedCmd > 0.5) {
      state = STATE_FEEDING;
      return;
    } else if (state == STATE_FEEDING && (minDist > 30 || feedCmd < 0.3)) {
      state = STATE_CRAWLING;
    }

    // 5. Grooming Trigger (when dirty)
    if (state == STATE_CRAWLING && cleanliness < 0.5 && random(1.0) < 0.03) {
      state = STATE_GROOMING;
      groomType = (random(1.0) > 0.5) ? 0 : 1;
      return;
    }

    // 6. Courtship / Oviposition Trigger
    if (state == STATE_CRAWLING && ovipositWingCmd > 0.6) {
      if (!isFemale && targetMate != null && minMateDist(targetMate) < 45) {
        state = STATE_COURTSHIP;
      } else if (isFemale && matureEggs > 0 && closestFood != null && closestFood.type == FOOD_PROTEIN && minDist < 35) {
        state = STATE_COURTSHIP;
      }
    }
  }

  float minMateDist(Fly m) {
    return (m == null) ? 999 : PVector.dist(pos, m.pos);
  }

  // Bounding & Glass Wall / Ceiling Contact
  void keepInCube(Environment env) {
    float margin = 8;
    // Floor
    if (pos.z < 0) {
      pos.z = 0;
      if (state == STATE_FLYING) state = STATE_LANDING;
    }
    // Ceiling
    if (pos.z > env.cubeH - margin) {
      pos.z = env.cubeH - margin;
      vel.z = -abs(vel.z) * 0.5;
    }
    // X Glass Walls
    if (pos.x < -env.cubeW/2 + margin) {
      pos.x = -env.cubeW/2 + margin;
      vel.x = abs(vel.x) * 0.5;
      heading = PI - heading;
    }
    if (pos.x > env.cubeW/2 - margin) {
      pos.x = env.cubeW/2 - margin;
      vel.x = -abs(vel.x) * 0.5;
      heading = PI - heading;
    }
    // Y Glass Walls
    if (pos.y < -env.cubeD/2 + margin) {
      pos.y = -env.cubeD/2 + margin;
      vel.y = abs(vel.y) * 0.5;
      heading = -heading;
    }
    if (pos.y > env.cubeD/2 - margin) {
      pos.y = env.cubeD/2 - margin;
      vel.y = -abs(vel.y) * 0.5;
      heading = -heading;
    }
  }

  // ---------------------------------------------------------------------------
  // 6 Legs Kinematics (Alternating Tripod Gait & Grooming)
  // ---------------------------------------------------------------------------
  void updateLegPositions(boolean onGround) {
    float[] sideOffsets = {-1, 1, -1, 1, -1, 1}; // L, R, L, R, L, R
    float[] longitudinalOffsets = {3.5, 3.5, 0.0, 0.0, -3.5, -3.5}; // Pro, Meso, Meta thorax

    for (int i = 0; i < 6; i++) {
      float side = sideOffsets[i];
      float longOff = longitudinalOffsets[i];

      // Base joint on thorax
      legBases[i].x = pos.x + cos(heading) * longOff - sin(heading) * (side * 3.2);
      legBases[i].y = pos.y + sin(heading) * longOff + cos(heading) * (side * 3.2);
      legBases[i].z = pos.z + 2.0;

      if (!onGround) {
        // Tucked aerodynamically against body during flight
        legTips[i].x = legBases[i].x + cos(heading) * (longOff * 0.5) - sin(heading) * (side * 2.5);
        legTips[i].y = legBases[i].y + sin(heading) * (longOff * 0.5) + cos(heading) * (side * 2.5);
        legTips[i].z = legBases[i].z - 1.2;
      } else if (state == STATE_GROOMING) {
        // Grooming routines
        if (groomType == 0) {
          // Front legs (0 & 1) sweep over head & compound eyes
          if (i == 0 || i == 1) {
            float sweep = sin(groomPhase) * 4.0;
            legTips[i].x = pos.x + cos(heading) * (6.5 + sweep) - sin(heading) * (side * 2.0);
            legTips[i].y = pos.y + sin(heading) * (6.5 + sweep) + cos(heading) * (side * 2.0);
            legTips[i].z = pos.z + 3.0 + abs(sweep) * 0.5;
          } else {
            defaultLegRest(i, side, longOff);
          }
        } else {
          // Hind legs (4 & 5) rub together and sweep folded wings
          if (i == 4 || i == 5) {
            float rub = sin(groomPhase) * 3.0;
            legTips[i].x = pos.x - cos(heading) * (6.0 + rub) - sin(heading) * (side * 1.5);
            legTips[i].y = pos.y - sin(heading) * (6.0 + rub) + cos(heading) * (side * 1.5);
            legTips[i].z = pos.z + 1.8 + abs(rub) * 0.4;
          } else {
            defaultLegRest(i, side, longOff);
          }
        }
      } else {
        // Alternating Tripod Walking Gait
        // Tripod 1: L1, R2, L3 (indices 0, 3, 4)
        // Tripod 2: R1, L2, R3 (indices 1, 2, 5)
        boolean isTripod1 = (i == 0 || i == 3 || i == 4);
        float phase = isTripod1 ? tripodPhase : (tripodPhase + PI);
        float swing = sin(phase);

        float legReach = (i < 2) ? 6.5 : (i < 4 ? 6.0 : 7.2);
        float stepForward = cos(phase) * 3.0;
        float lift = max(0, swing * 2.5);

        legTips[i].x = pos.x + cos(heading) * (longOff + stepForward) - sin(heading) * (side * legReach);
        legTips[i].y = pos.y + sin(heading) * (longOff + stepForward) + cos(heading) * (side * legReach);
        legTips[i].z = pos.z + lift;
      }
    }
  }

  void defaultLegRest(int i, float side, float longOff) {
    float reach = (i < 2) ? 6.0 : (i < 4 ? 5.5 : 6.8);
    legTips[i].x = pos.x + cos(heading) * longOff - sin(heading) * (side * reach);
    legTips[i].y = pos.y + sin(heading) * longOff + cos(heading) * (side * reach);
    legTips[i].z = pos.z;
  }

  // ---------------------------------------------------------------------------
  // 3D Isometric Diptera Rendering
  // ---------------------------------------------------------------------------
  void display(IsoCamera cam, boolean isSelected) {
    PVector sPos = cam.toScreen(pos.x, pos.y, pos.z);
    pushMatrix();
    pushStyle();

    // 1. Drop shadow on ground floor
    if (pos.z > 2) {
      PVector sShadow = cam.toScreen(pos.x, pos.y, 0);
      float shadowScale = map(pos.z, 0, 300, 1.0, 0.4);
      noStroke();
      fill(0, map(pos.z, 0, 300, 75, 15));
      ellipse(sShadow.x, sShadow.y, 14 * bodyScale * shadowScale, 9 * bodyScale * shadowScale);
    }

    // 2. Selection Ring & Telemetry Tag
    if (isSelected) {
      stroke(100, 220, 255, 200);
      strokeWeight(1.5);
      noFill();
      ellipse(sPos.x, sPos.y, 36 * bodyScale, 22 * bodyScale);
      
      // Floating identification tag
      fill(100, 220, 255);
      textAlign(CENTER, BOTTOM);
      textSize(9);
      String sexIcon = isFemale ? "♀ (Female)" : "♂ (Male)";
      text(sexIcon + " | " + brain.currentThought, sPos.x, sPos.y - 20);
    }

    // 3. Render 6 Legs
    stroke(30, 28, 25);
    strokeWeight(1.2);
    for (int i = 0; i < 6; i++) {
      PVector sBase = cam.toScreen(legBases[i].x, legBases[i].y, legBases[i].z);
      PVector sTip = cam.toScreen(legTips[i].x, legTips[i].y, legTips[i].z);
      // Knee joint (femur-tibia flexion)
      float kneeZ = (legBases[i].z + legTips[i].z) * 0.5 + 2.5;
      PVector sKnee = cam.toScreen((legBases[i].x + legTips[i].x)*0.5, (legBases[i].y + legTips[i].y)*0.5, kneeZ);
      line(sBase.x, sBase.y, sKnee.x, sKnee.y);
      line(sKnee.x, sKnee.y, sTip.x, sTip.y);
    }

    // 4. Render Dipteran Body (Abdomen, Thorax, Head)
    // Abdomen (posterior)
    float abdAngle = heading + PI;
    float abdX = pos.x + cos(abdAngle) * (6.0 * bodyScale);
    float abdY = pos.y + sin(abdAngle) * (6.0 * bodyScale);
    PVector sAbd = cam.toScreen(abdX, abdY, pos.z + 1.8);

    // Abdomen color: dark bronze with segmental bands
    fill(42, 38, 32);
    stroke(25, 22, 18);
    strokeWeight(1);
    ellipse(sAbd.x, sAbd.y, 11 * bodyScale, 8.5 * abdomenScale * bodyScale);
    // Abdominal stripes (Dipteran vittae)
    stroke(70, 65, 55, 160);
    line(sAbd.x - 3, sAbd.y - 3, sAbd.x - 3, sAbd.y + 3);
    line(sAbd.x + 1, sAbd.y - 3, sAbd.x + 1, sAbd.y + 3);

    // Telescopic Ovipositor (Females laying eggs)
    if (isFemale && ovipositorExtension > 0.05) {
      float oviX = pos.x + cos(abdAngle) * (12.0 * bodyScale);
      float oviY = pos.y + sin(abdAngle) * (12.0 * bodyScale);
      PVector sOvi = cam.toScreen(oviX, oviY, pos.z + 0.5);
      stroke(220, 200, 160);
      strokeWeight(1.5);
      line(sAbd.x, sAbd.y, sOvi.x, sOvi.y);
    }

    // Thorax (central motor powerhouse with flight muscles)
    fill(48, 44, 40);
    stroke(28, 25, 20);
    ellipse(sPos.x, sPos.y, 9.5 * bodyScale, 8.0 * bodyScale);

    // Halteres (Tiny oscillating gyroscopic clubs behind wings)
    if (state == STATE_FLYING) {
      float haltOsc = sin(halterePhase) * 3.0;
      PVector sHaltL = cam.toScreen(pos.x - sin(heading)*3.5, pos.y + cos(heading)*3.5, pos.z + 2.0 + haltOsc);
      PVector sHaltR = cam.toScreen(pos.x + sin(heading)*3.5, pos.y - cos(heading)*3.5, pos.z + 2.0 - haltOsc);
      stroke(255, 210, 80, 200);
      strokeWeight(1.0);
      line(sPos.x, sPos.y, sHaltL.x, sHaltL.y);
      line(sPos.x, sPos.y, sHaltR.x, sHaltR.y);
    }

    // Wings (Dipteran Kinematics)
    renderWings(cam, sPos);

    // Head (anterior)
    float headX = pos.x + cos(heading) * (5.5 * bodyScale);
    float headY = pos.y + sin(heading) * (5.5 * bodyScale);
    PVector sHead = cam.toScreen(headX, headY, pos.z + 2.2);

    fill(35, 32, 28);
    ellipse(sHead.x, sHead.y, 6.5 * bodyScale, 5.5 * bodyScale);

    // Large Compound Eyes (Dorsolateral)
    // Males have narrower frons (holoptic eyes closer together)
    float eyeSeparation = isFemale ? 2.4 : 1.4;
    PVector sEyeL = cam.toScreen(headX - sin(heading) * eyeSeparation, headY + cos(heading) * eyeSeparation, pos.z + 2.6);
    PVector sEyeR = cam.toScreen(headX + sin(heading) * eyeSeparation, headY - cos(heading) * eyeSeparation, pos.z + 2.6);

    // Eyes glow deep reddish brown
    fill(190, 35, 25);
    stroke(140, 20, 15);
    strokeWeight(0.8);
    ellipse(sEyeL.x, sEyeL.y, 4.0 * bodyScale, 4.2 * bodyScale);
    ellipse(sEyeR.x, sEyeR.y, 4.0 * bodyScale, 4.2 * bodyScale);

    // Proboscis extension when feeding
    if (proboscisExtend > 0.1) {
      float probX = headX + cos(heading) * (4.5 * proboscisExtend);
      float probY = headY + sin(heading) * (4.5 * proboscisExtend);
      PVector sProb = cam.toScreen(probX, probY, pos.z);
      stroke(80, 70, 55);
      strokeWeight(1.5);
      line(sHead.x, sHead.y, sProb.x, sProb.y);
    }

    popStyle();
    popMatrix();
  }

  // Render authentic Dipteran wings (folded flat vs high-speed aerodynamic blur)
  void renderWings(IsoCamera cam, PVector sPos) {
    if (state == STATE_FLYING || state == STATE_TAKEOFF) {
      // High-speed wing motion blur & venation
      float flapAngle = sin(wingPhase) * 0.85;
      
      // Semi-translucent aerodynamic wing blades
      fill(220, 240, 255, 65);
      stroke(180, 210, 240, 120);
      strokeWeight(0.8);

      // Left Wing
      pushMatrix();
      translate(sPos.x, sPos.y - 1);
      rotate(heading - HALF_PI + flapAngle * 0.4);
      ellipse(0, -14 * bodyScale, 7 * bodyScale, 24 * bodyScale);
      // Costa venation line
      line(0, 0, 0, -22 * bodyScale);
      popMatrix();

      // Right Wing
      pushMatrix();
      translate(sPos.x, sPos.y - 1);
      rotate(heading + HALF_PI - flapAngle * 0.4);
      ellipse(0, -14 * bodyScale, 7 * bodyScale, 24 * bodyScale);
      line(0, 0, 0, -22 * bodyScale);
      popMatrix();

    } else if (state == STATE_COURTSHIP && !isFemale) {
      // Male Courtship Song: One wing extended at 90 deg and vibrating rapidly!
      fill(220, 240, 255, 140);
      stroke(180, 210, 240, 180);
      strokeWeight(0.8);

      // Vibrating left wing
      pushMatrix();
      translate(sPos.x, sPos.y);
      rotate(heading - courtshipWingAngle + sin(courtshipBuzzPhase) * 0.15);
      ellipse(0, -12 * bodyScale, 6 * bodyScale, 20 * bodyScale);
      line(0, 0, 0, -18 * bodyScale);
      popMatrix();

      // Folded right wing
      pushMatrix();
      translate(sPos.x, sPos.y);
      rotate(heading + PI);
      ellipse(0, -9 * bodyScale, 5 * bodyScale, 17 * bodyScale);
      popMatrix();

    } else {
      // Resting / Landed: Wings folded flat over abdomen in classic housefly posture
      fill(210, 230, 250, 130);
      stroke(160, 190, 220, 160);
      strokeWeight(0.8);

      pushMatrix();
      translate(sPos.x, sPos.y);
      rotate(heading + PI - 0.12);
      ellipse(0, -9 * bodyScale, 5.2 * bodyScale, 18 * bodyScale);
      line(0, 0, 0, -16 * bodyScale);
      popMatrix();

      pushMatrix();
      translate(sPos.x, sPos.y);
      rotate(heading + PI + 0.12);
      ellipse(0, -9 * bodyScale, 5.2 * bodyScale, 18 * bodyScale);
      line(0, 0, 0, -16 * bodyScale);
      popMatrix();
    }
  }
}
