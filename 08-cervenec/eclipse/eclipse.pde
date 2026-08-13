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

final float SX      = W / 2.0;        // Sun / Moon centre
final float SY      = H / 2.0;
final float SUN_R   = 170;
final float MOON_R  = SUN_R * 1.032;  // just larger -> totality

void settings() {
  size(W, H);
  smooth(8);
}

void setup() {
  try {
    hudFont = loadFont("TerminessNFP-12.vlw");
  } catch (Exception e) {
    hudFont = createFont("SansSerif", 12);
  }
  noiseSeed(17);
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
  // background gradient (deep space, lighter toward the Sun)
  noStroke();
  for (int y = 0; y < H; y += 3) {
    float t = y / (float) H;
    fill(lerpColor(color(6, 10, 20), color(11, 17, 32), t));
    rect(0, y, W, 3);
  }

  drawStars();
  drawSun();
  drawCorona();
  drawMoon();
}

void drawStars() {
  blendMode(ADD);
  noStroke();
  randomSeed(3);
  for (int i = 0; i < 220; i++) {
    float x = random(W);
    float y = random(H);
    float b = random(35, 190);
    fill(200, 215, 255, b);
    float r = random(1) < 0.04 ? 1.5 : 0.8;
    ellipse(x, y, r, r);
  }
  blendMode(BLEND);
}

void drawSun() {
  // soft outer glow
  blendMode(ADD);
  noStroke();
  for (int i = 0; i < 14; i++) {
    float rr = SUN_R * (1.35 + i * 0.28);
    float al = 44 * (1 - i / 14.0);
    fill(255, 200, 130, al);
    ellipse(SX, SY, rr * 2, rr * 2);
  }
  blendMode(BLEND);

  // body: warm radial gradient
  for (int i = 0; i < 22; i++) {
    float rr = SUN_R * (1 - i / 22.0);
    float t = i / 22.0;
    fill(lerpColor(color(255, 244, 214), color(255, 150, 45), t));
    ellipse(SX, SY, rr * 2, rr * 2);
  }
}

void drawCorona() {
  blendMode(ADD);
  noStroke();

  // inner pearly layer hugging the Moon's limb
  for (int i = 0; i < 12; i++) {
    float rr = MOON_R * (1.03 + i * 0.10);
    float al = 150 * (1 - i / 12.0);
    fill(255, 252, 240, al);
    ellipse(SX, SY, rr * 2, rr * 2);
  }
  // outer cool-blue halo
  for (int i = 0; i < 12; i++) {
    float rr = MOON_R * (1.18 + i * 0.20);
    float al = 34 * (1 - i / 12.0);
    fill(150, 185, 255, al);
    ellipse(SX, SY, rr * 2, rr * 2);
  }

  // streamers — bezier tendrils radiating from the limb
  strokeWeight(1);
  randomSeed(9);
  for (int i = 0; i < 24; i++) {
    float a = random(TWO_PI);
    float r0 = MOON_R * 1.06;
    float r1 = MOON_R * (1.7 + random(2.0));
    float bend = random(-1, 1) * MOON_R * 0.8;
    float da = random(-0.18, 0.18);
    float cx = cos(a), cy = sin(a);
    float px = cos(a + da), py = sin(a + da);
    stroke(255, 250, 240, random(40, 110));
    bezier(SX + cx * r0, SY + cy * r0,
           SX + cx * r0 + px * bend + px * MOON_R * 0.35,
           SY + cy * r0 + py * bend + py * MOON_R * 0.35,
           SX + px * r1 - px * bend, SY + py * r1 - py * bend,
           SX + px * r1, SY + py * r1);
  }

  // diamond-ring glint at one limb
  fill(255, 250, 225, 230);
  float ga = -0.5;
  ellipse(SX + cos(ga) * MOON_R, SY + sin(ga) * MOON_R, MOON_R * 0.18, MOON_R * 0.18);

  blendMode(BLEND);
}

void drawMoon() {
  noStroke();
  fill(5, 6, 10);
  ellipse(SX, SY, MOON_R * 2, MOON_R * 2);
  noFill();
  stroke(190, 165, 140, 70);
  strokeWeight(1.5);
  ellipse(SX, SY, MOON_R * 2, MOON_R * 2);
  strokeWeight(1);
}

void drawHUD() {
  if (hudFont != null) {
    textFont(hudFont);
  }
  textAlign(LEFT, TOP);
  fill(150, 175, 225, 185);

  text("SOLAR ECLIPSE // 12 AUG 2026 // TOTALITY 02m18s", 14, 14);
  text("GAMMA +0.898   MAG 1.0386   PATH 294 KM   SAROS 126", 14, 28);
  text("GREATEST 17:46 UTC   MOON ~1.032x SUN", 14, 42);
}
