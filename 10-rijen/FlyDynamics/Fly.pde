// =============================================================================
// Fly.pde - Dipteran Biomechanics, Spatial Memory, Steady Flight & Saccades
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

  // Inter-saccadic cruising vs sharp saccade turns
  float saccadeTimer = 0;

  // Flight trajectory trace (short fading ribbon)
  ArrayList<PVector> flightTrail = new ArrayList<PVector>();
  final int MAX_TRAIL_LENGTH = 16;

  // Sexual Dimorphism
  boolean isFemale = true;
  float bodyScale = 1.0;
  
  // Female spermatheca (stores mate's brain and epigenetics for transgenerational inheritance)
  FlyBrain lastMateBrain = null;

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
  float landedDuration = 0;

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
  float trehalose = 0.85;  // Carbohydrate flight fuel (0.0 to 1.0)
  float protein = 0.2;     // Protein for vitellogenesis
  float hydration = 0.9;   // Water balance
  float cleanliness = 0.95;// Sensor cleanliness
  float bodyTemp = 24.0;   // Ectothermic temperature (°C)

  // Learning tracking
  float prevDistToFood = 9999;

  // Neuromorphic Brain & Vision
  FlyBrain brain;
  FlyVision vision;

  float proboscisExtend = 0;
  float respirationPulse = 0;

  Fly(float x, float y, float z) {
    pos = new PVector(x, y, z);
    vel = new PVector(random(-1.2, 1.2), random(-1.2, 1.2), random(-0.3, 0.3));
    acc = new PVector(0, 0, 0);
    heading = random(TWO_PI);
    saccadeTimer = random(1.0, 2.5);
    
    isFemale = (random(1.0) > 0.5);
    bodyScale = isFemale ? 1.08 : 0.92;

    brain = new FlyBrain();
    vision = new FlyVision();

    initLegs();
  }

  Fly(float x, float y, float z, FlyBrain inheritedBrain) {
    this(x, y, z);
    this.brain = inheritedBrain;
    this.bodyScale = isFemale ? (1.08 * brain.wingAspectMod) : (0.92 * brain.wingAspectMod);
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
    stateTimer += 0.016;

    // Safety checks against NaN
    if (Float.isNaN(pos.x) || Float.isNaN(pos.y) || Float.isNaN(pos.z)) pos.set(0, 0, 40);
    if (Float.isNaN(vel.x) || Float.isNaN(vel.y) || Float.isNaN(vel.z)) vel.set(0, 0, 0);

    // 1. THERMOREGULATION & METABOLISM
    float distToLight = PVector.dist(pos, env.lightPos);
    float targetTemp = map(constrain(distToLight, 30, 450), 30, 450, 32.0, 20.0);
    bodyTemp = lerp(bodyTemp, targetTemp, 0.02);
    wingFrequency = map(bodyTemp, 20.0, 32.0, 140.0, 220.0);

    // Energy consumption & Basal Recovery
    if (state == STATE_FLYING) {
      trehalose = max(0, trehalose - 0.00075);
      hydration = max(0, hydration - 0.00025);
      landedDuration = 0;
    } else {
      landedDuration += 0.016;
      trehalose = min(0.55, trehalose + 0.0004);
      hydration = max(0.1, hydration - 0.00008);
    }

    cleanliness = max(0.1, cleanliness - 0.00015);

    // Vitellogenesis in females
    if (isFemale && protein > 0.35 && matureEggs < 6) {
      vitellogenesis += 0.0014;
      if (vitellogenesis >= 1.0) {
        matureEggs++;
        protein = max(0, protein - 0.25);
        vitellogenesis = 0;
      }
    }

    // 2. VISUAL SIGHTING & WORKING MEMORY ACQUISITION ("What they have seen")
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
      if (f.type == 0) carbOdor += odorIntensity;
      else proteinOdor += odorIntensity;

      // Compound eye visual detection: store seen food location into working memory!
      if (d < 250) {
        brain.recordSeenFood(f.pos, f.type, max(0.4, 1.0 - d / 250.0));
      }
    }

    // Scan seen points of interest (dew on glass, warm perch wire)
    for (PointOfInterest poi : env.poiList) {
      float d = PVector.dist(pos, poi.pos);
      if (d < 250) {
        brain.recordSeenPoi(poi.pos, poi.type, max(0.4, 1.0 - d / 250.0));
      }
    }

    // Reinforcement Learning: Reward moving towards food!
    if (closestFood != null && prevDistToFood < 9000) {
      float deltaDist = prevDistToFood - minDist;
      if (deltaDist > 0.3) {
        brain.applyDopamineReward(constrain(deltaDist * 0.08, 0, 0.4));
      }
    }
    prevDistToFood = minDist;

    // Tarsal sugar taste
    float tarsalSugar = 0;
    if (closestFood != null && minDist < 22 && closestFood.type == 0 && state != STATE_FLYING) {
      tarsalSugar = 1.0;
    }

    // Sun / Light Compass bearing (Trigonometric wrap)
    PVector diffLight = PVector.sub(env.lightPos, pos);
    float rawCompass = atan2(diffLight.y, diffLight.x) - heading;
    float angleToLight = atan2(sin(rawCompass), cos(rawCompass));
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

    vision.update(pos, heading, pitch, env, swarm, this);

    PVector wind = env.getWindAt(pos);

    // 3. BRAIN COGNITIVE DELIBERATION (Thinking with spatial memory, needs & aero cues)
    brain.computeThinking(
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
      1.0 - hydration,
      pos,
      heading,
      bodyTemp,
      state,
      isFemale,
      env,
      wind
    );

    // 4. MOTOR STEERING & PROPORTIONAL TARGET GUIDANCE
    float wingThrustCmd = brain.outputs[0];
    float steerCmd = (brain.outputs[1] - 0.5) * 2.0;
    float pitchCmd = (brain.outputs[2] - 0.5) * 2.0;
    float jumpCmd = brain.outputs[3];
    float gaitCmd = brain.outputs[4];
    float feedCmd = brain.outputs[5];
    float ovipositWingCmd = brain.outputs[6];

    handleStateMachine(env, jumpCmd, feedCmd, ovipositWingCmd, closestFood, minDist);

    // 5. KINEMATIC INTEGRATION
    if (state == STATE_FLYING) {
      wingFold = min(1.0, wingFold + 0.18);
      wingPhase += (wingFrequency / 60.0) * TWO_PI * 0.08;
      halterePhase += (wingFrequency / 60.0) * TWO_PI * 0.08;

      if (trehalose <= 0.01) wingThrustCmd *= 0.2;

      // Update adaptive aero-navigation (crab-angle compensation & vertical trim)
      brain.updateAirNavigation(this, env, wind);

      saccadeTimer -= 0.016;

      // Target steering towards the calculated stimulus direction (Memory / Upwind / Casting)
      PVector stimDir = brain.stimulusDirection;
      float desiredYaw = atan2(stimDir.y, stimDir.x);
      float yawDiff = atan2(sin(desiredYaw - heading), cos(desiredYaw - heading));

      if (brain.activeBehavior == BEHAVIOR_CRUISE) {
        if (saccadeTimer <= 0) {
          heading += random(-1, 1) * random(0.6, 1.4); // Sharp saccadic turn
          saccadeTimer = random(1.6, 3.2); // Cruise straight for next few seconds
        }
        pitch = lerp(pitch, pitchCmd * 0.25, 0.05);
        roll = lerp(roll, -steerCmd * 0.4, 0.08);
      } else {
        // Deliberate flight towards stimuli
        heading = lerp(heading, heading + yawDiff, 0.08);
        float horizDist = sqrt(stimDir.x * stimDir.x + stimDir.y * stimDir.y);
        float desiredPitch = atan2(stimDir.z, max(0.1, horizDist));
        pitch = lerp(pitch, constrain(desiredPitch, -0.4, 0.4), 0.08);
        roll = lerp(roll, -yawDiff * 0.6, 0.12);
      }

      // Learned crab-angle steering: wings angle thrust into crosswind to cancel lateral drift!
      float thrustHeading = heading + brain.crabAngle;
      float thrustPitch = pitch + brain.pitchTrim;

      PVector thrust = new PVector(cos(thrustHeading) * cos(thrustPitch), sin(thrustHeading) * cos(thrustPitch), sin(thrustPitch));
      thrust.mult(max(0.7, wingThrustCmd * 2.3));
      acc.add(thrust);

      acc.add(env.gravity);
      acc.add(PVector.mult(wind, 0.14));

      vel.add(acc);
      vel.mult(0.93);
      vel.limit(4.4);
      pos.add(vel);
      acc.set(0, 0, 0);

      flightTrail.add(pos.copy());
      if (flightTrail.size() > MAX_TRAIL_LENGTH) {
        flightTrail.remove(0);
      }

      updateLegPositions(false);

    } else {
      if (flightTrail.size() > 0) flightTrail.remove(0);

      if (state == STATE_TAKEOFF) {
        wingFold = min(1.0, wingFold + 0.25);
        wingPhase += 0.8;
        pos.z += 4.2;
        vel.z = 2.5;
        if (stateTimer > 0.7 || pos.z > 16) {
          state = STATE_FLYING;
          stateTimer = 0;
        }

      } else if (state == STATE_LANDING) {
        vel.mult(0.65);
        pos.z = max(0, pos.z - 2.5);
        wingFold = max(0.0, wingFold - 0.12);
        pitch = lerp(pitch, -0.2, 0.1);

        if (pos.z <= 1.0) {
          pos.z = 0;
          vel.set(0, 0, 0);
          state = STATE_CRAWLING;
          stateTimer = 0;
          wingFold = 0.0;
        }
        updateLegPositions(true);

      } else if (state == STATE_CRAWLING) {
        wingFold = max(0.0, wingFold - 0.12);
        pos.z = 0;

        float crawlSpeed = max(0.5, gaitCmd * 1.5);

        // Targeted crawling toward remembered food location or nearby scent
        if (brain.hasActiveTarget()) {
          PVector target = brain.getActiveTarget();
          PVector toTarget = PVector.sub(target, pos);
          float desiredAngle = atan2(toTarget.y, toTarget.x);
          heading = lerp(heading, desiredAngle, 0.12);
        } else if (closestFood != null && minDist > 18) {
          PVector toFood = PVector.sub(closestFood.pos, pos);
          float foodAngle = atan2(toFood.y, toFood.x);
          heading = lerp(heading, foodAngle, 0.08);
        } else {
          heading += steerCmd * 0.06;
        }

        pos.x += cos(heading) * crawlSpeed;
        pos.y += sin(heading) * crawlSpeed;
        tripodPhase += crawlSpeed * 0.45;

        // Takeoff when rested or targeting memory
        if ((landedDuration > 3.0 && trehalose > 0.25 && random(1.0) < 0.05) || (brain.hasActiveTarget() && trehalose > 0.15)) {
          state = STATE_TAKEOFF;
          stateTimer = 0;
        }

        updateLegPositions(true);

      } else if (state == STATE_FEEDING) {
        pos.z = 0;
        wingFold = 0.0;
        proboscisExtend = lerp(proboscisExtend, 1.0, 0.15);

        if (closestFood != null && minDist < 24) {
          brain.recordSeenFood(closestFood.pos, closestFood.type, 1.0);

          if (closestFood.type == 0) { // FOOD_CARB
            closestFood.consume(0.14);
            trehalose = min(1.0, trehalose + 0.005);
            brain.applyDopamineReward(1.2);
            brain.foodFoundCount++;
          } else {
            closestFood.consume(0.12);
            protein = min(1.0, protein + 0.004);
            brain.applyDopamineReward(1.0);
            brain.foodFoundCount++;
          }
        } else {
          state = STATE_CRAWLING;
          stateTimer = 0;
        }
        updateLegPositions(true);

      } else if (state == STATE_GROOMING) {
        pos.z = 0;
        wingFold = 0.0;
        groomPhase += 0.22;
        cleanliness = min(1.0, cleanliness + 0.004);
        if (cleanliness >= 0.98 || landedDuration > 3.0) {
          state = STATE_CRAWLING;
          stateTimer = 0;
        }
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
              targetMate.lastMateBrain = this.brain; // Female stores father's brain and epigenetics
              targetMate.brain.applyDopamineReward(1.5);
              this.brain.applyDopamineReward(1.5);
              state = STATE_CRAWLING;
              stateTimer = 0;
            }
          }
        } else {
          if (matureEggs > 0 && closestFood != null && minDist < 35 && closestFood.type == 1) { // FOOD_PROTEIN
            ovipositorExtension = lerp(ovipositorExtension, 1.0, 0.15);
            if (ovipositorExtension > 0.85 && frameCount % 35 == 0) {
              // Pass maternal brain AND paternal stored brain for epigenetic inheritance!
              env.eggs.add(new Egg(pos.x + random(-4, 4), pos.y + random(-4, 4), 0, this.brain, this.lastMateBrain));
              matureEggs--;
              brain.applyDopamineReward(1.8);
              if (matureEggs <= 0) {
                ovipositorExtension = 0;
                state = STATE_CRAWLING;
                stateTimer = 0;
              }
            }
          }
        }
        updateLegPositions(true);
      }
    }

    // Hydration replenishment
    for (PointOfInterest poi : env.poiList) {
      if (poi.type == 0 && PVector.dist(pos, poi.pos) < 25) { // POI_WATER
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
      brain.applyDopamineReward(0.8);
      return;
    }

    // Voluntary takeoff triggered by brain target
    if ((jumpCmd > 0.65 || brain.hasActiveTarget()) 
        && (state == STATE_CRAWLING || state == STATE_GROOMING) && trehalose > 0.02) {
      state = STATE_TAKEOFF;
      stateTimer = 0;
      return;
    }

    // Minimum airborne duration (1.2s) prevents landing bounce
    if (state == STATE_FLYING && stateTimer > 1.2) {
      if (trehalose < 0.10 || (closestFood != null && minDist < 35 && pos.z < 45)) {
        state = STATE_LANDING;
        stateTimer = 0;
        return;
      }
    }

    if (state == STATE_CRAWLING && closestFood != null && minDist < 20 && feedCmd > 0.4) {
      state = STATE_FEEDING;
      stateTimer = 0;
      return;
    } else if (state == STATE_FEEDING && (minDist > 26 || feedCmd < 0.3)) {
      state = STATE_CRAWLING;
      stateTimer = 0;
    }

    if (state == STATE_CRAWLING && cleanliness < 0.4 && random(1.0) < 0.04) {
      state = STATE_GROOMING;
      groomType = (random(1.0) > 0.5) ? 0 : 1;
      stateTimer = 0;
      return;
    }

    if (state == STATE_CRAWLING && ovipositWingCmd > 0.6) {
      if (!isFemale && targetMate != null && minMateDist(targetMate) < 45) {
        state = STATE_COURTSHIP;
        stateTimer = 0;
      } else if (isFemale && matureEggs > 0 && closestFood != null && closestFood.type == 1 && minDist < 35) {
        state = STATE_COURTSHIP;
        stateTimer = 0;
      }
    }
  }

  float minMateDist(Fly m) {
    return (m == null) ? 999 : PVector.dist(pos, m.pos);
  }

  // Robust Boundary Reflection (Prevents flies pinning to walls!)
  void keepInCube(Environment env) {
    float margin = 8;
    if (pos.z < 0) {
      pos.z = 0;
      if (state == STATE_FLYING) {
        state = STATE_LANDING;
        stateTimer = 0;
      }
    }
    if (pos.z > env.cubeH - margin) {
      pos.z = env.cubeH - margin;
      vel.z = -abs(vel.z) * 0.5;
    }

    // Reflect X walls only if heading into the wall!
    if (pos.x < -env.cubeW/2 + margin) {
      pos.x = -env.cubeW/2 + margin + 1;
      vel.x = abs(vel.x) * 0.5;
      if (cos(heading) < 0) heading = PI - heading;
    }
    if (pos.x > env.cubeW/2 - margin) {
      pos.x = env.cubeW/2 - margin - 1;
      vel.x = -abs(vel.x) * 0.5;
      if (cos(heading) > 0) heading = PI - heading;
    }

    // Reflect Y walls only if heading into the wall!
    if (pos.y < -env.cubeD/2 + margin) {
      pos.y = -env.cubeD/2 + margin + 1;
      vel.y = abs(vel.y) * 0.5;
      if (sin(heading) < 0) heading = -heading;
    }
    if (pos.y > env.cubeD/2 - margin) {
      pos.y = env.cubeD/2 - margin - 1;
      vel.y = -abs(vel.y) * 0.5;
      if (sin(heading) > 0) heading = -heading;
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
  // 3D Isometric World Rendering: Tiny Fly Avatar + Fading Flight Ribbon
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
        float alpha = progress * 150;
        strokeWeight(lerp(0.5, 1.8, progress));
        stroke(isFemale ? color(200, 160, 255, alpha) : color(120, 210, 255, alpha));
        line(s1.x, s1.y, s2.x, s2.y);
      }
    }

    PVector sPos = cam.toScreen(pos.x, pos.y, pos.z);

    // 2. Drop shadow on ground
    if (pos.z > 1) {
      PVector sShadow = cam.toScreen(pos.x, pos.y, 0);
      float shadowAlpha = map(pos.z, 0, 300, 90, 15);
      noStroke();
      fill(0, shadowAlpha);
      ellipse(sShadow.x, sShadow.y, 6.0, 3.5);
    }

    // 3. Selection Indicator & Aerodynamic Flight Vectors
    if (isSelected) {
      stroke(100, 220, 255, 180);
      strokeWeight(1);
      noFill();
      rect(sPos.x - 8, sPos.y - 8, 16, 16);
      
      fill(100, 220, 255);
      textAlign(CENTER, BOTTOM);
      text((isFemale ? "F" : "M") + " F" + brain.generation, sPos.x, sPos.y - 9);

      // Aerodynamic Flight Vectors (Visualizing learned crab-angle and ground track)
      if (state == STATE_FLYING) {
        float tYaw = heading + brain.crabAngle;
        PVector sThrust = cam.toScreen(pos.x + cos(tYaw) * 16, pos.y + sin(tYaw) * 16, pos.z + sin(pitch + brain.pitchTrim) * 12);
        stroke(255, 215, 60, 160); // Yellow: Thrust direction
        line(sPos.x, sPos.y, sThrust.x, sThrust.y);

        PVector sTrack = cam.toScreen(pos.x + vel.x * 6, pos.y + vel.y * 6, pos.z + vel.z * 6);
        stroke(80, 240, 150, 210); // Green: Resultant Ground Track
        line(sPos.x, sPos.y, sTrack.x, sTrack.y);
      }
    }

    // 4. Tiny Fly Avatar: Pixel Chitin Tinted by Speciation Strain
    pushMatrix();
    translate(sPos.x, sPos.y);

    float wingSpan = 5.0 * brain.wingAspectMod;

    if (state == STATE_FLYING || state == STATE_TAKEOFF) {
      noStroke();
      fill(220, 240, 255, 130);
      ellipse(-wingSpan * 0.5, -1, wingSpan, 2.5);
      ellipse(wingSpan * 0.5, -1, wingSpan, 2.5);

      fill(brain.speciesChitinColor);
      ellipse(0, 0, 4.5, 3.5);

      fill(190, 30, 20);
      ellipse(-1.2, -1.2, 1.5, 1.5);
      ellipse(1.2, -1.2, 1.5, 1.5);

    } else {
      stroke(30, 28, 25);
      strokeWeight(0.8);
      line(-2.5, -2, 2.5, -2);
      line(-3, 0, 3, 0);
      line(-2.5, 2, 2.5, 2);

      noStroke();
      fill(brain.speciesChitinColor);
      ellipse(0, 0, 4.5, 3.2);

      fill(210, 230, 250, 150);
      ellipse(0, 0.5, 3.2, 4.5 * brain.wingAspectMod);

      fill(190, 30, 20);
      ellipse(-1.0, -1.4, 1.4, 1.4);
      ellipse(1.0, -1.4, 1.4, 1.4);
    }

    popMatrix();
    popStyle();
  }

  // ---------------------------------------------------------------------------
  // Dedicated Bottom Inspector: High-Detail Pixel-Art Fly Diagram (UNSCALED TEXT)
  // ---------------------------------------------------------------------------
  void displayBottomDiagram(float cx, float cy) {
    pushStyle();

    // 1. Outer Hexapod Leg System (Pixel-Art Joints)
    stroke(45, 40, 35);
    strokeWeight(1.8);

    for (int i = 0; i < 6; i++) {
      float side = (i % 2 == 0) ? -1 : 1;
      float longY = cy + (i < 2 ? -32 : (i < 4 ? -12 : 12));

      float bx = cx + side * 18;
      float by = longY;

      boolean isTripod1 = (i == 0 || i == 3 || i == 4);
      float phase = isTripod1 ? tripodPhase : (tripodPhase + PI);
      float swing = (state == STATE_CRAWLING) ? sin(phase) * 10 : 0;
      float stepForward = (state == STATE_CRAWLING) ? cos(phase) * 9 : 0;

      if (state == STATE_GROOMING) {
        if (groomType == 0 && (i == 0 || i == 1)) {
          stepForward = -15 + sin(groomPhase) * 10;
          bx += side * sin(groomPhase) * 4;
        } else if (groomType == 1 && (i == 4 || i == 5)) {
          stepForward = 15 + sin(groomPhase) * 9;
          bx -= side * 8;
        }
      }

      float kx = cx + side * (38 + abs(swing) * 0.4);
      float ky = longY + stepForward * 0.5;

      float tx = cx + side * (56 + (i == 2 || i == 3 ? 9 : 3));
      float ty = longY + (i < 2 ? -18 : (i > 3 ? 26 : 0)) + stepForward;

      line(bx, by, kx, ky);
      line(kx, ky, tx, ty);

      fill(80, 70, 60);
      noStroke();
      rect(tx - 2, ty - 2, 4, 4);
      stroke(45, 40, 35);
      strokeWeight(1.8);
    }

    // 2. Anatomical Body Shell
    noStroke();
    fill(38, 34, 30);
    ellipse(cx, cy - 60, 42, 32);

    fill(48, 44, 38);
    ellipse(cx, cy - 14, 48, 58);

    fill(42, 38, 32);
    ellipse(cx, cy + 54, 42, 72);
    stroke(75, 70, 58);
    strokeWeight(1);
    line(cx - 18, cy + 35, cx + 18, cy + 35);
    line(cx - 20, cy + 52, cx + 20, cy + 52);
    line(cx - 18, cy + 69, cx + 18, cy + 69);
    line(cx - 12, cy + 85, cx + 12, cy + 85);

    if (isFemale && ovipositorExtension > 0.1) {
      stroke(240, 225, 180);
      strokeWeight(2.0);
      line(cx, cy + 89, cx, cy + 89 + ovipositorExtension * 24);
      fill(255, 240, 200);
      rect(cx - 2, cy + 89 + ovipositorExtension * 24 - 2, 4, 4);
    }

    // 3. Wings
    renderDiagramWings(cx, cy);

    // 4. Halteres
    float haltOsc = (state == STATE_FLYING) ? sin(halterePhase) * 5.0 : 0;
    stroke(255, 200, 70);
    strokeWeight(1.5);
    line(cx - 22, cy - 2, cx - 38, cy - 2 + haltOsc);
    line(cx + 22, cy - 2, cx + 38, cy - 2 - haltOsc);
    fill(255, 215, 80);
    rect(cx - 41, cy - 5 + haltOsc, 5, 5);
    rect(cx + 36, cy - 5 - haltOsc, 5, 5);

    // 5. Internal Nervous System Overlay
    fill(200, 32, 22);
    stroke(140, 20, 15);
    strokeWeight(1);
    float eyeSep = isFemale ? 14 : 10;
    ellipse(cx - eyeSep, cy - 62, 14, 24);
    ellipse(cx + eyeSep, cy - 62, 14, 24);

    fill(255, 245, 120);
    noStroke();
    rect(cx - 2, cy - 72, 4, 4);
    rect(cx - 6, cy - 69, 3, 3);
    rect(cx + 3, cy - 69, 3, 3);

    stroke(190, 210, 235);
    strokeWeight(1.2);
    line(cx - 6, cy - 74, cx - 14, cy - 88);
    line(cx + 6, cy - 74, cx + 14, cy - 88);
    line(cx - 14, cy - 88, cx - 20, cy - 92);
    line(cx + 14, cy - 88, cx + 20, cy - 92);

    noFill();
    stroke(80, 210, 255);
    strokeWeight(1.2);
    ellipse(cx - 9, cy - 60, 8, 15);
    ellipse(cx + 9, cy - 60, 8, 15);

    fill(255, 215, 80);
    stroke(255, 235, 110);
    strokeWeight(1);
    ellipse(cx, cy - 57, 11, 8);

    fill(225, 85, 175);
    noStroke();
    rect(cx - 9, cy - 55, 5, 5);
    rect(cx + 4, cy - 55, 5, 5);

    stroke(110, 225, 255);
    strokeWeight(2.0);
    line(cx, cy - 45, cx, cy - 25);

    fill(60, 190, 240);
    stroke(110, 230, 255);
    strokeWeight(1.2);
    ellipse(cx, cy - 14, 19, 30);

    stroke(80, 200, 255);
    strokeWeight(1);
    line(cx, cy - 20, cx - 26, cy - 32);
    line(cx, cy - 20, cx + 26, cy - 32);
    line(cx, cy - 14, cx - 31, cy - 12);
    line(cx, cy - 14, cx + 31, cy - 12);
    line(cx, cy - 8, cx - 26, cy + 11);
    line(cx, cy - 8, cx + 26, cy + 11);
    line(cx, 0, cx, cy + 65);

    for (ActionPotential ap : brain.spikes) {
      PVector sp = brain.getSpikePosition(ap.tract, ap.progress);
      noStroke();
      fill(ap.col);
      rect(cx + sp.x - 2, cy + sp.y - 2, 4, 4);
      fill(255);
      rect(cx + sp.x - 1, cy + sp.y - 1, 2, 2);
    }

    if (proboscisExtend > 0.1) {
      stroke(90, 75, 60);
      strokeWeight(2.0);
      line(cx, cy - 74, cx, cy - 74 - proboscisExtend * 14);
    }

    // Direct 1:1 Pixel Labels
    fill(150, 195, 240);
    textAlign(CENTER, TOP);
    text("COMPOUND EYES", cx, cy - 104);
    text("RING ATTRACTOR (CX)", cx, cy - 50);
    text("THORACIC CPG", cx, cy + 4);
    text("HALTERES", cx - 48, cy - 18);
    text(isFemale ? "OVIPOSITOR" : "GENITALIA", cx, cy + 94);

    popStyle();
  }

  void renderDiagramWings(float cx, float cy) {
    if (state == STATE_FLYING || state == STATE_TAKEOFF) {
      float flap = sin(wingPhase) * 16;
      fill(220, 240, 255, 75);
      stroke(180, 215, 245, 140);
      strokeWeight(1);

      pushMatrix();
      translate(cx - 11, cy - 19);
      rotate(-HALF_PI + radians(flap));
      ellipse(0, -32, 17, 58);
      line(0, 0, 0, -54);
      popMatrix();

      pushMatrix();
      translate(cx + 11, cy - 19);
      rotate(HALF_PI - radians(flap));
      ellipse(0, -32, 17, 58);
      line(0, 0, 0, -54);
      popMatrix();

    } else if (state == STATE_COURTSHIP && !isFemale) {
      fill(220, 240, 255, 140);
      stroke(180, 215, 245, 180);
      strokeWeight(1);

      pushMatrix();
      translate(cx - 11, cy - 19);
      rotate(-HALF_PI * 0.9 + sin(courtshipBuzzPhase) * 0.15);
      ellipse(0, -30, 16, 54);
      line(0, 0, 0, -50);
      popMatrix();

      pushMatrix();
      translate(cx + 11, cy - 19);
      rotate(PI + 0.1);
      ellipse(0, -25, 14, 48);
      line(0, 0, 0, -44);
      popMatrix();

    } else {
      fill(215, 235, 255, 135);
      stroke(170, 205, 235, 160);
      strokeWeight(1);

      pushMatrix();
      translate(cx - 6, cy - 19);
      rotate(PI - 0.12);
      ellipse(0, -27, 15, 54);
      line(0, 0, 0, -50);
      popMatrix();

      pushMatrix();
      translate(cx + 6, cy - 19);
      rotate(PI + 0.12);
      ellipse(0, -27, 15, 54);
      line(0, 0, 0, -50);
      popMatrix();
    }
  }
}
