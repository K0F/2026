// =============================================================================
// Oscilloscope.pde - Real-Time Vector Scope & Phosphor Trace Decay
// Direct architectural bridge to XYScope & NurbsRayPlotter
// =============================================================================

class VectorScope {
  int bufferSize = 320;
  PVector[] traceBuffer = new PVector[bufferSize];
  float[] intensityBuffer = new float[bufferSize];
  int writeHead = 0;
  
  VectorScope() {
    for (int i = 0; i < bufferSize; i++) {
      traceBuffer[i] = new PVector(0, 0);
      intensityBuffer[i] = 0.0;
    }
  }
  
  void pushSample(float x, float y, float intensity) {
    traceBuffer[writeHead] = new PVector(x, y);
    intensityBuffer[writeHead] = intensity;
    writeHead = (writeHead + 1) % bufferSize;
  }
  
  void render(float originX, float originY, float w, float h) {
    // Oscilloscope scope CRT casing
    fill(5, 8, 12, 240);
    stroke(25, 45, 60);
    strokeWeight(1);
    rect(originX, originY, w, h);
    
    // Graticule reticle lines (CRT crosshair & circular phosphor radar)
    stroke(14, 28, 38);
    line(originX + w * 0.5, originY, originX + w * 0.5, originY + h);
    line(originX, originY + h * 0.5, originX + w, originY + h * 0.5);
    noFill();
    ellipse(originX + w * 0.5, originY + h * 0.5, w * 0.84, h * 0.84);
    ellipse(originX + w * 0.5, originY + h * 0.5, w * 0.42, h * 0.42);
    
    // Sub-graticule dots
    stroke(18, 36, 48);
    for (int gx = 1; gx < 8; gx++) {
      float lx = originX + (w / 8.0) * gx;
      point(lx, originY + h * 0.5 - 2);
      point(lx, originY + h * 0.5 + 2);
    }
    
    // Trace continuous beam with phosphor decay
    float centerX = originX + w * 0.5;
    float centerY = originY + h * 0.5;
    float scaleFactor = w * 0.40;
    
    noFill();
    for (int i = 0; i < bufferSize - 1; i++) {
      int idx1 = (writeHead + i) % bufferSize;
      int idx2 = (writeHead + i + 1) % bufferSize;
      
      float ageNorm = (float)i / bufferSize; // 0.0 oldest, 1.0 newest
      float alpha = pow(ageNorm, 2.0) * 255.0;
      
      PVector p1 = traceBuffer[idx1];
      PVector p2 = traceBuffer[idx2];
      
      float x1 = centerX + p1.x * scaleFactor;
      float y1 = centerY + p1.y * scaleFactor;
      float x2 = centerX + p2.x * scaleFactor;
      float y2 = centerY + p2.y * scaleFactor;
      
      // Phosphor Cyan / Green beam with velocity-based intensity
      stroke(30, 245, 175, alpha);
      strokeWeight(0.6 + ageNorm * 1.6);
      line(x1, y1, x2, y2);
      
      // Phosphor glowing dot at the beam head
      if (i == bufferSize - 2) {
        fill(225, 255, 245);
        noStroke();
        ellipse(x2, y2, 4.5, 4.5);
      }
    }
    
    // Corner CRT notation
    fill(70, 110, 130);
    text("CH1: DIPOLE_X  CH2: DIPOLE_Y", originX + 10, originY + h - 8);
  }
}
