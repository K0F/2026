// =============================================================================
// NeuralField.pde - Harmonic Coordinate Field with Fourier Positional Encoding
// Modern neural field synthesis of 2009 (Neural32) + 2024 (seriesnn)
// Fast real-time convergence with closed-loop sampling for spatial neurons
// =============================================================================

class NeuralField {
  int numFreqs = 4;
  int numIn = 8;       // Fourier features: [sin(2^k * u), cos(2^k * u), sin(2^k * v), cos(2^k * v)]
  int numHidden = 20;  // Latent representation dimensionality
  int numOut = 1;
  
  float[][] w1 = new float[numIn][numHidden];
  float[] b1 = new float[numHidden];
  float[] w2 = new float[numHidden];
  float b2 = 0.0;
  
  float[] hiddenAct = new float[numHidden];
  float[] inFeatures = new float[numIn];
  float outputAct = 0.0;
  
  float learningRate = 0.038;
  float currentMSE = 0.0;
  long trainingSteps = 0;
  
  NeuralField() {
    for (int i = 0; i < numIn; i++) {
      for (int h = 0; h < numHidden; h++) {
        w1[i][h] = random(-1.0, 1.0) * sqrt(2.0 / numIn);
      }
    }
    for (int h = 0; h < numHidden; h++) {
      b1[h] = random(-0.2, 0.2);
      w2[h] = random(-1.0, 1.0) * sqrt(2.0 / numHidden);
    }
    b2 = random(-0.1, 0.1);
  }
  
  // Compute Fourier Positional Encodings for coordinate (u, v)
  void encodeFeatures(float u, float v) {
    float freq = 1.0;
    int idx = 0;
    for (int k = 0; k < numFreqs; k++) {
      inFeatures[idx++] = sin(TWO_PI * freq * u);
      inFeatures[idx++] = cos(TWO_PI * freq * u);
      inFeatures[idx++] = sin(TWO_PI * freq * v);
      inFeatures[idx++] = cos(TWO_PI * freq * v);
      freq *= 2.0;
      if (idx >= numIn) break;
    }
  }
  
  // Fast Tanh activation: tanh(x) = (exp(2x)-1)/(exp(2x)+1)
  float tanhAct(float x) {
    float ex = exp(constrain(2.0 * x, -12.0, 12.0));
    return (ex - 1.0) / (ex + 1.0);
  }
  
  float dTanh(float y) {
    return 1.0 - y * y;
  }
  
  float forward(float u, float v) {
    encodeFeatures(u, v);
    
    // Hidden Layer with Tanh
    for (int h = 0; h < numHidden; h++) {
      float sum = b1[h];
      for (int i = 0; i < numIn; i++) {
        sum += inFeatures[i] * w1[i][h];
      }
      hiddenAct[h] = tanhAct(sum);
    }
    
    // Output Layer with Sigmoid
    float outSum = b2;
    for (int h = 0; h < numHidden; h++) {
      outSum += hiddenAct[h] * w2[h];
    }
    outputAct = 1.0 / (1.0 + exp(-constrain(outSum, -10.0, 10.0)));
    return outputAct;
  }
  
  void trainStep(float u, float v, float target) {
    float pred = forward(u, v);
    float err = target - pred;
    currentMSE = currentMSE * 0.994 + (err * err) * 0.006;
    trainingSteps++;
    
    // Output gradient (sigmoid)
    float outDelta = err * (pred * (1.0 - pred));
    
    // Hidden gradients (tanh)
    for (int h = 0; h < numHidden; h++) {
      float hiddenDelta = (outDelta * w2[h]) * dTanh(hiddenAct[h]);
      w2[h] += learningRate * outDelta * hiddenAct[h];
      b1[h] += learningRate * hiddenDelta;
      for (int i = 0; i < numIn; i++) {
        w1[i][h] += learningRate * hiddenDelta * inFeatures[i];
      }
    }
    b2 += learningRate * outDelta;
  }
  
  // Closed-loop query: Sample field potential at normalized coordinate (u, v)
  float sampleAt(float u, float v) {
    return forward(u, v);
  }
  
  void renderField(float x, float y, float w, float h, int resolution) {
    float cellW = w / resolution;
    float cellH = h / resolution;
    noStroke();
    
    for (int i = 0; i < resolution; i++) {
      float u = (float)i / resolution;
      for (int j = 0; j < resolution; j++) {
        float v = (float)j / resolution;
        float val = forward(u, v);
        
        // Analog phosphor luminance
        int lum = int(val * 200.0);
        fill(lum * 0.15, lum * 0.90, lum * 0.70);
        rect(x + i * cellW, y + j * cellH, cellW, cellH);
      }
    }
    
    stroke(35, 42, 50);
    noFill();
    rect(x, y, w, h);
  }
}
