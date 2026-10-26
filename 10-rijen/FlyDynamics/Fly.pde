// =============================================================================
// Fly.pde - Dipteran Biomechanics, Flight Trails, Bioenergetics & Learning
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
  float heading = 0;
  float pitch = 0;
  float roll = 0;

  // Flight trajectory trace (short fading ribbon)
  ArrayList<PVector> flightTrail = new ArrayList<PVector>();
  final int MAX_TRAIL_LENGTH = 22; // Not too long, elegant trace

  // Sexual Dimorphism
  boolean isFemale = true;
  float bodyScale = 1.0;
  
  // Oviposition & Vitellogenesis (Females)
  float vitellogenesis = 0.0;
  int matureEggs = 0;
  float ovipositorExtension = 0;
  
  // Courtship display (Males)
  float courtshipWingAngle = 0;
  float courtshipBuzzPhase = 0;
  Fly targetMate = null;

  // Behavior state
  int state = STATE_FLYING;
  float stateTimer = 0;

  // Biomechanics
  float wingFold = 1.0;
  float wingPhase = 0;
  float wingFrequency = 185.0; // Hz
  float halterePhase = 0;

  // 6 Legs (Alternating Tripod Gait)
  PVector[] legBases = new PVector[6];
  PVector[] legTips = new PVector[6];
  float tripodPhase = 0;
  int groomType = 0;
  float groomPhase = 0;

  // Bioenergetics & Homeostasis
  float trehalose = 0.85;  // Carbohydrate flight fuel
  float protein = 0.2;     // Protein for vitellogenesis
  float hydration = 0.9;   // Water balance
  float cleanliness = 0.95;// Sensor cleanliness
  float bodyTemp = 24.0;   // Ectothermic temperature (°C)

  // Learning & Gradient Navigation tracking
  float prevDistToFood = 9999;

  // Neuromorphic Brain & Vision
  FlyBrain brain;
  FlyVision vision;

  // Proboscis feeding apparatus
  float proboscisExtend = 0;
  float respirationPulse = 0;

  Fly(float x, float y, float z) {
    pos = new PVector(x, y, z);
    vel = new PVector(random(-1.2, 1.2), random(-1.2, 1.2), random(-0.5, 0.5));
    acc = new PVector(0, 0, 0);
    heading = random(TWO_PI);
    
    isFemale = (random(1.0) > 0.5);
    bodyScale = isFemale ? 1.08 : 0.92;

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
    float distToLight = PVector.dist(pos, env.lightPos);
    float targetTemp = map(constrain(distToLight, 30, 450), 30, 450, 32.0, 20.0);
    bodyTemp = lerp(bodyTemp, targetTemp, 0.02);
    wingFrequency = map(bodyTemp, 20.0, 32.0, 140.0, 220.0);

    // Energy consumption
    if (state == STATE_FLYING) {
      trehalose = max(0, trehalose - 0.00075);
      hydration = max(0, hydration - 0.00025);
    } else if (state == STATE_CRAWLING) {
      trehalose = max(0, trehalose - 0.00015);
      hydration = max(0, hydration - 0.00010);
    } else {
      trehalose = max(0, trehalose - 0.00005);
    }

    cleanliness = max(0.1, cleanliness - 0.00018);

    // Vitellogenesis in females
    if (isFemale && protein > 0.35 && matureEggs < 6) {
      vitellogenesis += 0.0014;
      if (vitellogenesis >= 1.0) {
        matureEggs++;
        protein = max(0, protein - 0.25);
        vitellogenesis = 0;
      }
    }

    // 2. SENSORY INFLUX & LEARNING GRADIENT
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

    // Reinforcement Learning: Reward moving towards food!
    if (closestFood != null && prevDistToFood < 9000) {
      float deltaDist = prevDistToFood - minDist;
      if (deltaDist > 0.4) {
        // Positive dopamine reinforcement for effective heading
        brain.applyDopamineReward(constrain(deltaDist * 0.06, 0, 0.4));
      }
    }
    prevDistToFood = minDist;

    // Tarsal sugar taste
    float tarsalSugar = 0;
    if (closestFood != null && minDist < 20 && closestFood.type == FOOD_CARB && state != STATE_FLYING) {
      tarsalSugar = 1.0;
    }

    // Sun / Light Compass bearing
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
      1.0 - trehalose,
      isFemale ? (1.0 - protein) : (targetMate != null ? 0.8 : 0.1),
      1.0 - hydration
    );

    // 4. MOTOR ACTUATION & STATE MACHINE
    float wingThrustCmd = brain.outputs[0];
    float steerCmd = (brain.outputs[1] - 0.5) * 2.0;
    float pitchCmd = (brain.outputs[2] - 0.5) * 2.0;
    float jumpCmd = brain.outputs[3];
    float gaitCmd = brain.outputs[4];
    float feedCmd = brain.outputs[5];
    float ovipositWingCmd = brain.outputs[6];

    handleStateMachine(env, jumpCmd, feedCmd, ovipositWingCmd, closestFood, minDist);

    // 5. KINEMATIC INTEGRATION
    PVector wind = env.getWindAt(pos);

    if (state == STATE_FLYING) {
      wingFold = min(1.0, wingFold + 0.18);
      wingPhase += (wingFrequency / 60.0) * TWO_PI * 0.08;
      halterePhase += (wingFrequency / 60.0) * TWO_PI * 0.08;

      if (trehalose <= 0.01) wingThrustCmd *= 0.2;

      heading += steerCmd * 0.11;
      pitch = lerp(pitch, pitchCmd * 0.45, 0.1);
      roll = lerp(roll, -steerCmd * 0.55, 0.12);

      PVector thrust = new PVector(cos(heading) * cos(pitch), sin(heading) * cos(pitch), sin(pitch));
      thrust.mult(wingThrustCmd * 2.4);
      acc.add(thrust);

      acc.add(env.gravity);
      acc.add(PVector.mult(wind, 0.12));

      vel.add(acc);
      vel.mult(0.93);
      pos.add(vel);
      acc.set(0, 0, 0);

      // Record flight trail point (fading trace)
      flightTrail.add(pos.copy());
      if (flightTrail.size() > MAX_TRAIL_LENGTH) {
        flightTrail.remove(0);
      }

      updateLegPositions(false);

    } else {
      // Clear flight trail smoothly when landed
      if (flightTrail.size() > 0) flightTrail.remove(0);

      if (state == STATE_TAKEOFF) {
        wingFold = min(1.0, wingFold + 0.25);
        wingPhase += 0.8;
        pos.z += 4.0;
        vel.z = 2.4;
        stateTimer += 0.12;
        if (stateTimer > 0.8 || pos.z > 16) state = STATE_FLYING;

      } else if (state == STATE_LANDING) {
        vel.mult(0.65);
        pos.z = max(0, pos.z - 2.2);
        wingFold = max(0.0, wingFold - 0.1);
        pitch = lerp(pitch, -0.2, 0.1);

        if (pos.z <= 0.5) {
          pos.z = 0;
          vel.set(0, 0, 0);
          state = STATE_CRAWLING;
          wingFold = 0.0;
        }
        updateLegPositions(true);

      } else if (state == STATE_CRAWLING) {
        wingFold = max(0.0, wingFold - 0.12);
        pos.z = 0;

        float crawlSpeed = gaitCmd * 1.5;
        heading += steerCmd * 0.06;
        pos.x += cos(heading) * crawlSpeed;
        pos.y += sin(heading) * crawlSpeed;
        tripodPhase += crawlSpeed * 0.45;

        updateLegPositions(true);

      } else if (state == STATE_FEEDING) {
        pos.z = 0;
        wingFold = 0.0;
        proboscisExtend = lerp(proboscisExtend, 1.0, 0.15);

        if (closestFood != null && minDist < 22) {
          if (closestFood.type == FOOD_CARB) {
            closestFood.consume(0.14);
            trehalose = min(1.0, trehalose + 0.004);
            brain.applyDopamineReward(1.2);
            brain.foodFoundCount++;
          } else {
            closestFood.consume(0.12);
            protein = min(1.0, protein + 0.0035);
            brain.applyDopamineReward(1.0);
            brain.foodFoundCount++;
          }
        }
        updateLegPositions(true);

      } else if (state == STATE_GROOMING) {
        pos.z = 0;
        wingFold = 0.0;
        groomPhase += 0.22;
        cleanliness = min(1.0, cleanliness + 0.0035);
        if (cleanliness >= 0.98) state = STATE_CRAWLING;
        updateLegPositions(true);

      } else if (state == STATE_COURTSHIP) {
        pos.z = 0;
        if (!isFemale) {
          courtshipWingAngle = lerp(courtshipWingAngle, HALF_PI * 0.85, 0.1);
          courtshipBuzzPhase += 0.5;
          if (targetMate != null) {
            PVector d = PVector.sub(targetMate.pos, pos);
            heading = lerp(heading, atan2(d.y, d.x), 0.1);
            if (PVector.dist(pos, targetMate.pos) < 18) {
              targetMate.brain.applyDopamineReward(1.2);
              this.brain.applyDopamineReward(1.2);
              state = STATE_CRAWLING;
            }
          }
        } else {
          if (matureEggs > 0 && closestFood != null && minDist < 35 && closestFood.type == FOOD_PROTEIN) {
            ovipositorExtension = lerp(ovipositorExtension, 1.0, 0.15);
            if (ovipositorExtension > 0.85 && frameCount % 35 == 0) {
              env.eggs.add(new Egg(pos.x + random(-4, 4), pos.y + random(-4, 4), 0, this.brain));
              matureEggs--;
              brain.applyDopamineReward(1.5);
              if (matureEggs <= 0) {
                ovipositorExtension = 0;
                state = STATE_CRAWLING;
              }
            }
          }
        }
        updateLegPositions(true);
      }
    }

    // Hydration replenishment
    for (PointOfInterest poi : env.poiList) {
      if (poi.type == POI_WATER && PVector.dist(pos, poi.pos) < 25) {
        hydration = min(1.0, hydration + 0.004);
        brain.applyDopamineReward(0.4);
      }
    }

    keepInCube(env);
  }

  void handleStateMachine(Environment env, float jumpCmd, float feedCmd, float ovipositWingCmd, Food closestFood, float minDist) {
    if (vision.loomingFactor > 0.35 && state != STATE_FLYING && state != STATE_TAKEOFF) {
      state = STATE_TAKEOFF;
      stateTimer = 0;
      brain.applyDopamineReward(0.8); // Escape relief!
      return;
    }

    if (jumpCmd > 0.75 && (state == STATE_CRAWLING || state == STATE_GROOMING) && trehalose > 0.05) {
      state = STATE_TAKEOFF;
      stateTimer = 0;
      return;
    }

    if (state == STATE_FLYING && (trehalose < 0.15 || (closestFood != null && minDist < 45 && pos.z < 60))) {
      state = STATE_LANDING;
      return;
    }

    if (state == STATE_CRAWLING && closestFood != null && minDist < 22 && feedCmd > 0.5) {
      state = STATE_FEEDING;
      return;
    } else if (state == STATE_FEEDING && (minDist > 28 || feedCmd < 0.3)) {
      state = STATE_CRAWLING;
    }

    if (state == STATE_CRAWLING && cleanliness < 0.5 && random(1.0) < 0.03) {
      state = STATE_GROOMING;
      groomType = (random(1.0) > 0.5) ? 0 : 1;
      return;
    }

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

  void keepInCube(Environment env) {
    float margin = 6;
    if (pos.z < 0) {
      pos.z = 0;
      if (state == STATE_FLYING) state = STATE_LANDING;
    }
    if (pos.z > env.cubeH - margin) {
      pos.z = env.cubeH - margin;
      vel.z = -abs(vel.z) * 0.5;
    }
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

  void updateLegPositions(boolean onGround) {
    float[] sideOffsets = {-1, 1, -1, 1, -1, 1};
    float[] longitudinalOffsets = {3.5, 3.5, 0.0, 0.0, -3.5, -3.5};

    for (int i = 0; i < 6; i++) {
      float side = sideOffsets[i];
      float longOff = longitudinalOffsets[i];

      legBases[i].x = pos.x + cos(heading) * longOff - sin(heading) * (side * 3.2);
      legBases[i].y = pos.y + sin(heading) * longOff + cos(heading) * (side * 3.2);
      legBases[i].z = pos.z + 2.0;

      if (!onGround) {
        legTips[i].x = legBases[i].x + cos(heading) * (longOff * 0.5) - sin(heading) * (side * 2.5);
        legTips[i].y = legBases[i].y + sin(heading) * (longOff * 0.5) + cos(heading) * (side * 2.5);
        legTips[i].z = legBases[i].z - 1.2;
      } else if (state == STATE_GROOMING) {
        if (groomType == 0) {
          if (i == 0 || i == 1) {
            float sweep = sin(groomPhase) * 4.0;
            legTips[i].x = pos.x + cos(heading) * (6.5 + sweep) - sin(heading) * (side * 2.0);
            legTips[i].y = pos.y + sin(heading) * (6.5 + sweep) + cos(heading) * (side * 2.0);
            legTips[i].z = pos.z + 3.0 + abs(sweep) * 0.5;
          } else {
            defaultLegRest(i, side, longOff);
          }
        } else {
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
  // 3D Isometric World Rendering: Realistic Tiny Fly Avatar + Flight Trace
  // ---------------------------------------------------------------------------
  void displayInWorld(IsoCamera cam, boolean isSelected) {
    pushStyle();

    // 1. Flight Trace Ribbon (Graceful, not too long)
    if (flightTrail.size() > 1) {
      noFill();
      for (int i = 0; i < flightTrail.size() - 1; i++) {
        PVector p1 = flightTrail.get(i);
        PVector p2 = flightTrail.get(i + 1);
        PVector s1 = cam.toScreen(p1.x, p1.y, p1.z);
        PVector s2 = cam.toScreen(p2.x, p2.y, p2.z);
        
        float progress = map(i, 0, flightTrail.size() - 1, 0, 1);
        float alpha = progress * 160;
        strokeWeight(lerp(0.5, 1.8, progress));
        stroke(isFemale ? color(200, 160, 255, alpha) : color(120, 210, 255, alpha));
        line(s1.x, s1.y, s2.x, s2.y);
      }
    }

    PVector sPos = cam.toScreen(pos.x, pos.y, pos.z);

    // 2. Drop shadow on ground (Tiny realistic shadow speck)
    if (pos.z > 1) {
      PVector sShadow = cam.toScreen(pos.x, pos.y, 0);
      float shadowAlpha = map(pos.z, 0, 300, 90, 15);
      noStroke();
      fill(0, shadowAlpha);
      ellipse(sShadow.x, sShadow.y, 6.0, 3.5);
    }

    // 3. Selection Indicator Ring
    if (isSelected) {
      stroke(100, 220, 255, 180);
      strokeWeight(1.2);
      noFill();
      ellipse(sPos.x, sPos.y, 18, 12);
      
      // Specimen ID
      fill(100, 220, 255);
      textAlign(CENTER, BOTTOM);
      textSize(8);
      text((isFemale ? "♀" : "♂"), sPos.x, sPos.y - 8);
    }

    // 4. Tiny Fly Avatar: Just a few pixels wide!
    pushMatrix();
    translate(sPos.x, sPos.y);

    if (state == STATE_FLYING || state == STATE_TAKEOFF) {
      // Flying Avatar: Tiny body speck + rapid wing motion blur
      // Wing motion blur
      noStroke();
      fill(220, 240, 255, 130);
      ellipse(-2.5, -1, 5, 2.5);
      ellipse(2.5, -1, 5, 2.5);

      // Body speck (dark brownish black ~4 pixels)
      fill(35, 30, 28);
      ellipse(0, 0, 4.5, 3.5);

      // Reddish ommatidia eye specks
      fill(190, 30, 20);
      ellipse(-1.2, -1.2, 1.5, 1.5);
      ellipse(1.2, -1.2, 1.5, 1.5);

    } else {
      // Landed / Crawling Avatar: Tiny folded wings over body + minute legs
      // Legs (minute black ticks)
      stroke(30, 28, 25);
      strokeWeight(0.8);
      line(-2.5, -2, 2.5, -2);
      line(-3, 0, 3, 0);
      line(-2.5, 2, 2.5, 2);

      // Body & folded wings
      noStroke();
      fill(38, 34, 30);
      ellipse(0, 0, 4.5, 3.2);

      // Folded wing translucency
      fill(210, 230, 250, 150);
      ellipse(0, 0.5, 3.2, 4.5);

      // Eye dots
      fill(190, 30, 20);
      ellipse(-1.0, -1.4, 1.4, 1.4);
      ellipse(1.0, -1.4, 1.4, 1.4);
    }

    popMatrix();
    popStyle();
  }

  // ---------------------------------------------------------------------------
  // Dedicated Bottom Inspector: High-Detail Anatomical & Biomechanical Fly Diagram
  // ---------------------------------------------------------------------------
  void displayBottomDiagram(float cx, float cy, float scale) {
    pushMatrix();
    pushStyle();
    translate(cx, cy);
    scale(scale);

    // 1. Outer Hexapod Leg System (Animated Alternating Tripod Gait or Grooming)
    stroke(45, 40, 35);
    strokeWeight(2.2);

    for (int i = 0; i < 6; i++) {
      float side = (i % 2 == 0) ? -1 : 1;
      float longY = (i < 2) ? -42 : (i < 4 ? -16 : 14);

      // Base joint
      float bx = side * 24;
      float by = longY;

      // Animated leg kinematics
      boolean isTripod1 = (i == 0 || i == 3 || i == 4);
      float phase = isTripod1 ? tripodPhase : (tripodPhase + PI);
      float swing = (state == STATE_CRAWLING) ? sin(phase) * 14 : 0;
      float stepForward = (state == STATE_CRAWLING) ? cos(phase) * 12 : 0;

      // Grooming leg action in diagram
      if (state == STATE_GROOMING) {
        if (groomType == 0 && (i == 0 || i == 1)) {
          stepForward = -20 + sin(groomPhase) * 14;
          bx += side * sin(groomPhase) * 6;
        } else if (groomType == 1 && (i == 4 || i == 5)) {
          stepForward = 20 + sin(groomPhase) * 12;
          bx -= side * 10;
        }
      }

      // Knee (Femur-Tibia joint)
      float kx = side * (52 + abs(swing) * 0.4);
      float ky = longY + stepForward * 0.5;

      // Tarsal tip (Foot contact with pulvilli)
      float tx = side * (75 + (i == 2 || i == 3 ? 12 : 4));
      float ty = longY + (i < 2 ? -24 : (i > 3 ? 34 : 0)) + stepForward;

      // Coxa-femur line
      line(bx, by, kx, ky);
      // Tibia-tarsus line
      line(kx, ky, tx, ty);

      // Adhesive pulvilli foot pad dot
      fill(80, 70, 60);
      noStroke();
      ellipse(tx, ty, 4.5, 4.5);
      stroke(45, 40, 35);
      strokeWeight(2.2);
    }

    // 2. Anatomical Cutaway Body Shell
    noStroke();
    // Head Capsule
    fill(38, 34, 30, 220);
    ellipse(0, -78, 54, 42);

    // Thorax (Powerhouse with flight muscles DLM/DVM)
    fill(48, 44, 38, 230);
    ellipse(0, -18, 64, 76);

    // Abdomen with bronze segments
    fill(42, 38, 32, 230);
    ellipse(0, 70, 56, 95);
    // Transverse segmental lines
    stroke(75, 70, 58, 180);
    strokeWeight(1.5);
    line(-24, 45, 24, 45);
    line(-26, 68, 26, 68);
    line(-23, 90, 23, 90);
    line(-16, 110, 16, 110);

    // Telescopic Ovipositor (Females)
    if (isFemale && ovipositorExtension > 0.1) {
      stroke(240, 225, 180);
      strokeWeight(3.0);
      line(0, 115, 0, 115 + ovipositorExtension * 32);
      fill(255, 240, 200);
      ellipse(0, 115 + ovipositorExtension * 32, 5, 5);
    }

    // 3. Wings (Folded flat vs vibrating vs flapping)
    renderDiagramWings();

    // 4. Halteres (Oscillating Gyroscopic Clubs)
    float haltOsc = (state == STATE_FLYING) ? sin(halterePhase) * 6.0 : 0;
    stroke(255, 200, 70);
    strokeWeight(2.0);
    line(-28, -2, -50, -2 + haltOsc);
    line(28, -2, 50, -2 - haltOsc);
    fill(255, 215, 80);
    ellipse(-50, -2 + haltOsc, 7, 7);
    ellipse(50, -2 - haltOsc, 7, 7);

    // 5. Internal Nervous System & Action Potentials Overlay
    // Compound Eyes (Left & Right)
    fill(200, 32, 22);
    stroke(140, 20, 15);
    strokeWeight(1.2);
    float eyeSep = isFemale ? 18 : 13;
    ellipse(-eyeSep, -80, 18, 32);
    ellipse(eyeSep, -80, 18, 32);

    // 3 Dorsal Ocelli
    fill(255, 245, 120);
    noStroke();
    ellipse(0, -92, 4, 4);
    ellipse(-5, -88, 3.5, 3.5);
    ellipse(5, -88, 3.5, 3.5);

    // Antennae (Johnston's organ & arista)
    stroke(190, 210, 235);
    strokeWeight(1.6);
    line(-8, -96, -18, -114);
    line(8, -96, 18, -114);
    line(-18, -114, -26, -120);
    line(18, -114, 26, -120);

    // Optic Lobes
    noFill();
    stroke(80, 210, 255, 190);
    strokeWeight(1.5);
    ellipse(-11, -78, 10, 20);
    ellipse(11, -78, 10, 20);

    // Central Complex (CX Compass)
    fill(255, 215, 80, 210);
    stroke(255, 235, 110);
    strokeWeight(1.2);
    ellipse(0, -74, 14, 10);

    // Mushroom Bodies (MB Olfactory Learning)
    fill(225, 85, 175, 210);
    noStroke();
    ellipse(-8, -68, 7, 7);
    ellipse(8, -68, 7, 7);

    // Ventral Nerve Cord descent
    stroke(110, 225, 255);
    strokeWeight(2.5);
    line(0, -58, 0, -32);

    // Thoracic-Abdominal Ganglion (TAG)
    fill(60, 190, 240, 220);
    stroke(110, 230, 255);
    strokeWeight(1.5);
    ellipse(0, -18, 24, 38);

    // Radiating Motor Nerves
    stroke(80, 200, 255, 170);
    strokeWeight(1.2);
    line(0, -26, -34, -42);
    line(0, -26, 34, -42);
    line(0, -18, -40, -16);
    line(0, -18, 40, -16);
    line(0, -10, -34, 14);
    line(0, -10, 34, 14);

    // Abdominal Nerve Cord
    line(0, 0, 0, 85);

    // Glowing Action Potentials traveling down nerves
    for (ActionPotential ap : brain.spikes) {
      PVector sp = brain.getSpikePosition(ap.tract, ap.progress);
      noStroke();
      fill(ap.col);
      ellipse(sp.x * 1.3, sp.y * 1.3, 6, 6);
      fill(255, 220);
      ellipse(sp.x * 1.3, sp.y * 1.3, 3, 3);
    }

    // Proboscis extension
    if (proboscisExtend > 0.1) {
      stroke(90, 75, 60);
      strokeWeight(3.0);
      line(0, -96, 0, -96 - proboscisExtend * 18);
    }

    // Labels
    fill(150, 195, 240);
    textAlign(CENTER, TOP);
    textSize(8.5);
    text("COMPOUND EYES & OCELLI", 0, -135);
    text("CENTRAL COMPLEX (COMPASS)", 0, -62);
    text("THORACIC GANGLION & CPG", 0, 5);
    text("HALTERES", -62, -18);
    text(isFemale ? "OVIPOSITOR" : "GENITALIA", 0, 122);

    popStyle();
    popMatrix();
  }

  void renderDiagramWings() {
    if (state == STATE_FLYING || state == STATE_TAKEOFF) {
      // High-speed wing flapping blur
      float flap = sin(wingPhase) * 18;
      fill(220, 240, 255, 75);
      stroke(180, 215, 245, 140);
      strokeWeight(1.2);

      pushMatrix();
      translate(-14, -24);
      rotate(-HALF_PI + radians(flap));
      ellipse(0, -42, 22, 75);
      line(0, 0, 0, -70);
      popMatrix();

      pushMatrix();
      translate(14, -24);
      rotate(HALF_PI - radians(flap));
      ellipse(0, -42, 22, 75);
      line(0, 0, 0, -70);
      popMatrix();

    } else if (state == STATE_COURTSHIP && !isFemale) {
      // Male Courtship Song: One wing unfurled at 90 deg and vibrating
      fill(220, 240, 255, 140);
      stroke(180, 215, 245, 180);
      strokeWeight(1.2);

      pushMatrix();
      translate(-14, -24);
      rotate(-HALF_PI * 0.9 + sin(courtshipBuzzPhase) * 0.15);
      ellipse(0, -38, 20, 68);
      line(0, 0, 0, -62);
      popMatrix();

      pushMatrix();
      translate(14, -24);
      rotate(PI + 0.1);
      ellipse(0, -32, 18, 62);
      line(0, 0, 0, -56);
      popMatrix();

    } else {
      // Folded flat over abdomen in classic Diptera posture
      fill(215, 235, 255, 135);
      stroke(170, 205, 235, 160);
      strokeWeight(1.2);

      pushMatrix();
      translate(-8, -24);
      rotate(PI - 0.12);
      ellipse(0, -34, 19, 68);
      line(0, 0, 0, -62);
      popMatrix();

      pushMatrix();
      translate(8, -24);
      rotate(PI + 0.12);
      ellipse(0, -34, 19, 68);
      line(0, 0, 0, -62);
      popMatrix();
    }
  }
}
