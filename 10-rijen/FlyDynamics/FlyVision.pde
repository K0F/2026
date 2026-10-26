// =============================================================================
// FlyVision.pde - Compound Eye Low-Res Pixel Vision & Optical Flow Detector
// =============================================================================
// Features of Dipteran Compound Eyes:
// - Hexagonal ommatidia sampling grid (Left & Right eye hemifields)
// - Fast motion detection (Reichardt correlation / Lobula Plate HS & VS cells)
// - Looming shadow expansion detection (Giant Fiber trigger)
// - Spectral sensitivity: UV/Visible light, Carbs (amber), Protein (magenta), Water (cyan)
// =============================================================================

class FlyVision {
  // Low-resolution pixel dimensions (Left Eye: 14x12, Right Eye: 14x12 -> 28x12 total)
  int gridW = 28;
  int gridH = 12;
  
  // Current and previous luminance buffer
  float[][] pixels;
  float[][] prevPixels;
  color[][] colorBuffer;
  
  // Optical flow / Looming threat metric
  float loomingFactor = 0.0;
  float motionIntensity = 0.0;
  float horizontalSlip = 0.0; // Left-right optical flow for yaw correction

  // Field of view parameters (horizontal ~220 deg, vertical ~120 deg)
  float fovH = radians(220);
  float fovV = radians(115);

  FlyVision() {
    pixels = new float[gridW][gridH];
    prevPixels = new float[gridW][gridH];
    colorBuffer = new color[gridW][gridH];
  }

  // Update vision by ray-projecting the 3D terrarium onto the fly's compound retinas
  void update(PVector flyPos, float heading, float pitch, Environment env, ArrayList<Fly> swarm, Fly self) {
    // 1. Shift buffer for motion detection
    for (int x = 0; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) {
        prevPixels[x][y] = pixels[x][y];
        pixels[x][y] = 0.06; // Ambient darkness
        colorBuffer[x][y] = color(14, 20, 28);
      }
    }

    // 2. Project Ceiling Light Source
    projectTarget(flyPos, heading, pitch, env.lightPos, 55, color(255, 245, 170), 1.0);

    // 3. Project Food Sources (Carbs = Amber, Protein = Magenta)
    for (Food f : env.foods) {
      color fCol = (f.type == FOOD_CARB) ? color(255, 215, 60) : color(230, 80, 160);
      projectTarget(flyPos, heading, pitch, f.pos, 38, fCol, 0.9);
    }

    // 4. Project Points of Interest (Water dew, Warm perches)
    for (PointOfInterest poi : env.poiList) {
      projectTarget(flyPos, heading, pitch, poi.pos, 28, poi.col, 0.7);
    }

    // 5. Project other flies in swarm
    for (Fly other : swarm) {
      if (other != self) {
        float d = PVector.dist(flyPos, other.pos);
        if (d < 190) {
          color oCol = other.isFemale ? color(180, 140, 255) : color(120, 200, 255);
          projectTarget(flyPos, heading, pitch, other.pos, 16, oCol, 0.75);
        }
      }
    }

    // 6. Project Looming Swatter Threat
    if (env.threatActive) {
      projectTarget(flyPos, heading, pitch, env.threatPos, env.threatRadius, color(255, 30, 30), 1.3);
    }

    // 7. Motion & Looming computation (Lobula Plate Lobula Giant Detector)
    float diffSum = 0;
    float centerDiff = 0;
    float borderDiff = 0;
    float leftDiff = 0;
    float rightDiff = 0;

    for (int x = 0; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) {
        float delta = abs(pixels[x][y] - prevPixels[x][y]);
        diffSum += delta;

        if (x < gridW/2) leftDiff += delta;
        else rightDiff += delta;

        float distFromCenter = dist(x, y, gridW/2.0, gridH/2.0);
        if (distFromCenter < 4.5) {
          centerDiff += delta;
        } else {
          borderDiff += delta;
        }
      }
    }

    motionIntensity = lerp(motionIntensity, diffSum / (gridW * gridH), 0.25);
    horizontalSlip = lerp(horizontalSlip, (rightDiff - leftDiff) / (gridW * gridH), 0.2);
    
    float loomRaw = (centerDiff * 1.8 + borderDiff * 2.2) * 2.5;
    loomingFactor = lerp(loomingFactor, constrain(loomRaw, 0, 1.0), 0.35);
  }

  void projectTarget(PVector eyePos, float heading, float pitch, PVector targetPos, float radius, color col, float intensity) {
    PVector diff = PVector.sub(targetPos, eyePos);
    float dist = diff.mag();
    if (dist < 1.0) return;

    float targetYaw = atan2(diff.y, diff.x) - heading;
    while (targetYaw > PI) targetYaw -= TWO_PI;
    while (targetYaw < -PI) targetYaw += TWO_PI;

    float targetPitch = atan2(diff.z, sqrt(diff.x * diff.x + diff.y * diff.y)) - pitch;

    if (abs(targetYaw) < fovH/2 && abs(targetPitch) < fovV/2) {
      float px = map(targetYaw, -fovH/2, fovH/2, 0, gridW);
      float py = map(targetPitch, fovV/2, -fovV/2, 0, gridH);

      float angularSize = max(1.0, map(radius / dist, 0.05, 0.8, 1, 6));

      int minX = max(0, int(px - angularSize/2));
      int maxX = min(gridW - 1, int(px + angularSize/2));
      int minY = max(0, int(py - angularSize/2));
      int maxY = min(gridH - 1, int(py + angularSize/2));

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          pixels[x][y] = min(1.0, pixels[x][y] + intensity);
          colorBuffer[x][y] = blendColor(colorBuffer[x][y], col, ADD);
        }
      }
    }
  }

  float getLeftLuminance() {
    float sum = 0;
    for (int x = 0; x < gridW/2; x++) {
      for (int y = 0; y < gridH; y++) sum += pixels[x][y];
    }
    return sum / ((gridW/2) * gridH);
  }

  float getRightLuminance() {
    float sum = 0;
    for (int x = gridW/2; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) sum += pixels[x][y];
    }
    return sum / ((gridW/2) * gridH);
  }

  // ---------------------------------------------------------------------------
  // Low-Res Pixel Compound Eye HUD Viewport (Pixel Art Aesthetic)
  // ---------------------------------------------------------------------------
  void displayHUD(float px, float py, float pw, float ph) {
    pushStyle();
    fill(10, 16, 26);
    stroke(55, 95, 140);
    strokeWeight(1);
    rect(px, py, pw, ph);

    // Title
    fill(180, 225, 255);
    textAlign(LEFT, TOP);
    text("COMPOUND EYE (28x12 PIXELS)", px + 8, py + 8);
    
    // Looming threat indicator
    if (loomingFactor > 0.28) {
      fill(255, 50, 50);
      textAlign(RIGHT, TOP);
      text("! LOOM THREAT: " + nf(loomingFactor * 100, 0, 0) + "% !", px + pw - 8, py + 8);
    }

    // Draw the low-res pixel grid
    float gridStartX = px + 8;
    float gridStartY = py + 24;
    float cellW = (pw - 20) / gridW;
    float cellH = (ph - 38) / gridH;

    for (int x = 0; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) {
        color c = colorBuffer[x][y];
        fill(c);
        stroke(18, 28, 40);
        strokeWeight(1);
        
        float renderX = gridStartX + x * cellW;
        if (x >= gridW/2) renderX += 4; // Mid-eye septum separation gap
        
        rect(renderX, gridStartY + y * cellH, cellW - 1, cellH - 1);
      }
    }

    // Optical Flow vector arrow (motion slip)
    if (abs(horizontalSlip) > 0.05) {
      stroke(255, 205, 50);
      strokeWeight(1);
      float flowCenterX = px + pw/2;
      float flowY = py + ph - 8;
      line(flowCenterX, flowY, flowCenterX + horizontalSlip * 110, flowY);
    }

    // Eye labels
    fill(130, 170, 215);
    textAlign(CENTER, BOTTOM);
    text("LEFT EYE", gridStartX + (gridW/4) * cellW, py + ph - 2);
    text("RIGHT EYE", gridStartX + 4 + (3 * gridW/4) * cellW, py + ph - 2);

    popStyle();
  }
}
