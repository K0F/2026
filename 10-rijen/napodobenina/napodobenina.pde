int totalPoints = 300; // Počet bodů po obvodu
float factor = 2.0;    // Počáteční násobitel

void setup() {
  size(600, 800);
  smooth();
}

void draw() {
  background(34); // Tmavě šedé pozadí (stejné jako na vašich snímcích)
  
  translate(width / 2, height / 2);
  float radius = width * 0.38;

  // Jemný obrys kruhu
  stroke(255, 40);
  noFill();
  ellipse(0, 0, radius * 2, radius * 2);

  // Vykreslení spojnic
  stroke(255, 90);
  strokeWeight(0.8);

  for (int i = 0; i < totalPoints; i++) {
    // Počáteční bod
    PVector a = getVector(i, totalPoints, radius);
    
    // Cílový bod podle modulární aritmetiky
    float target = (i * factor) % totalPoints;
    PVector b = getVector(target, totalPoints, radius);
    
    line(a.x, a.y, b.x, b.y);
  }

  // Zvýšení faktoru pro animaci sekvence
  factor += 0.01;
  
  // Uložení do sekvence .tga (odkomentujte pro export):
  // saveFrame("######.tga");
}

PVector getVector(float index, int total, float radius) {
  float angle = map(index, 0, total, 0, TWO_PI) - HALF_PI;
  float x = radius * cos(angle);
  float y = radius * sin(angle);
  return new PVector(x, y);
}
