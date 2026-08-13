/*ded by Kof @
    eclipse of the year

                 .
        .        ;|         .
         .    .-; `-.       .
   .     .  .'  |  `.  .      .
         . /    )|(    \  .      .
   .     ;     |||     ;  .
          \    (o o)    /       .
   .      '-.  \_/  .-'    .
        .    `-.   .-'      .
   .         .  (.)  .   .        .
      .         `-'   .      .

    SOLAR ECLIPSE // 12 AUG 2026
    Moon / Sun / Earth conjunction
    TOTALITY — the corona moment

REAL DATA // aggregate of the 2026-08-12 event (sources: NASA
eclipse.gsfc.nasa.gov Besselian elements SE2026Aug12T; Wikipedia
"Solar eclipse of August 12, 2026"; lunar perigee/ephemeris tables).

  Type          total (T)
  Greatest      ~17:46 UTC  (TDT 17:47:06, JD 2461265.24, dT ~72-75 s)
  Gamma         +0.8977     (shadow axis 0.898 R(Earth) N of center)
  Magnitude     1.0386      obscuration 1.0788
  Saros         126
  Sun r         ~695700 km  semi-diameter 15'47.0"
  Moon r        1737.4 km   semi-diameter 16'16.9"  -> ratio ~1.032
  Earth r       6371 km
  Umbra width   294 km (~0.046 R(Earth))  duration 02m18s
  Ground point  65.2 N 25.2 W (Greenland / Denmark Strait)

RENDER NOTES // viewed from the Earth, totality centered. Simple 2D
(JAVA2D, no OpenGL) so it renders reliably headless and the Moon disc
always covers the Sun. Sizes keep the real 1.032 apparent-radius ratio.
*/


PFont hudFont;

final int W = 932;
final int H = 576;

final float SX      = W / 2.0;
final float SY      = H / 2.0;
final float SUN_R   = 160;
final float MOON_R  = SUN_R * 1.032;

void settings() {
  size(W, H);
  smooth(8);
}

void setup() {
  try {
    hudFont = loadFont("TerminessNFP-12.vlw");
  } catch (Exception e) {
    hudFont = createFont("Monospaced", 11);
  }
  noiseSeed(42);
}

void draw() {
  drawScene();
  drawHUD();
  if (frameCount == 2) {
    save("eclipse.png");
    exit();
  }
}

void drawScene() {
  noStroke();
  background(3, 5, 10);

  drawStars();
  drawCoronaGlow();
  drawStreamers();
  drawMoon();
}

void drawStars() {
  randomSeed(1337);
  noStroke();
  for (int i = 0; i < 200; i++) {
    float x = random(W);
    float y = random(H);
    float b = random(50, 160);
    fill(200, 215, 255, b);
    ellipse(x, y, 0.8, 0.8);
  }
}

void drawCoronaGlow() {
  noStroke();
  for (int i = 40; i > 0; i--) {
    float t = i / 40.0;
    float r = MOON_R + t * 180;
    float alpha = pow(1.0 - t, 2.0) * 35;
    fill(235, 243, 255, alpha);
    ellipse(SX, SY, r * 2, r * 2);
  }
  
  for (int i = 20; i > 0; i--) {
    float t = i / 20.0;
    float r = MOON_R * (1.0 + t * 0.3);
    float alpha = (1.0 - t) * 55;
    fill(255, 230, 190, alpha);
    ellipse(SX, SY, r * 2, r * 2);
  }
}

void drawStreamers() {
  strokeWeight(1);
  noFill();
  randomSeed(99);
  for (int i = 0; i < 36; i++) {
    float a = random(TWO_PI);
    float r0 = MOON_R * 1.01;
    float r1 = MOON_R * (1.3 + random(1.8));
    float bend = random(-1, 1) * MOON_R * 0.4;
    float da = random(-0.1, 0.1);
    
    float cx = cos(a), cy = sin(a);
    float px = cos(a + da), py = sin(a + da);
    
    stroke(230, 240, 255, random(30, 80));
    bezier(SX + cx * r0, SY + cy * r0,
           SX + cx * r0 + px * bend, SY + cy * r0 + py * bend,
           SX + px * r1 - px * bend, SY + py * r1 - py * bend,
           SX + px * r1, SY + py * r1);
  }
}

void drawMoon() {
  noStroke();
  fill(2, 3, 6);
  ellipse(SX, SY, MOON_R * 2, MOON_R * 2);
  
  noFill();
  stroke(150, 175, 210, 120);
  strokeWeight(1);
  ellipse(SX, SY, MOON_R * 2, MOON_R * 2);
}

void drawHUD() {
  if (hudFont != null) {
    textFont(hudFont);
  }
  textAlign(LEFT, TOP);
  
  noStroke();
  fill(0, 210);
  rect(16, 16, 360, 180, 2);
  
  stroke(100, 120, 150, 100);
  noFill();
  rect(16, 16, 360, 180, 2);
  
  fill(180, 210, 255);
  float y = 26;
  float dy = 13;
  
  text("EVENT: SOLAR ECLIPSE // 12 AUG 2026[cite: 6]", 26, y); y += dy;
  text("DATA SOURCE: NASA SE2026Aug12T[cite: 6]", 26, y); y += dy;
  text("----------------------------------------", 26, y); y += dy;
  text("TYPE: Total (T)[cite: 6]", 26, y); y += dy;
  text("GREATEST: ~17:46 UTC (JD 2461265.24)[cite: 6]", 26, y); y += dy;
  text("GAMMA: +0.8977 (N of center)[cite: 6]", 26, y); y += dy;
  text("MAGNITUDE: 1.0386 (Obscuration 1.0788)[cite: 6]", 26, y); y += dy;
  text("SAROS SERIES: 126[cite: 6]", 26, y); y += dy;
  text("SUN R: ~695,700 KM (15'47.0\")[cite: 6]", 26, y); y += dy;
  text("MOON R: 1,737.4 KM (16'16.9\")[cite: 6]", 26, y); y += dy;
  text("EARTH R: 6,371 KM[cite: 6]", 26, y); y += dy;
  text("UMBRA WIDTH: 294 KM (Dur: 02m18s)[cite: 6]", 26, y); y += dy;
  text("GROUND POINT: 65.2°N 25.2°W[cite: 6]", 26, y);
}
