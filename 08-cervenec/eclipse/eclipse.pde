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

RENDER NOTES // illustrative screen-space composition. Everything is
drawn flat in one 2D ortho pass (painter's order, depth test off), so
the Moon disc reliably covers the Sun. Sizes keep the real ratios:
Moon/Sun apparent radius 1.032, gamma shadow offset, umbra width.
*/

PFont hudFont;

final int W = 932;
final int H = 576;

// illustrative layout (screen pixels)
final float SX      = 466;            // Sun / Moon centre
final float SY      = 195;
final float SUN_R   = 150;
final float MOON_R  = SUN_R * 1.032;  // just larger -> totality
final float EX      = 715;            // Earth centre
final float EY      = 462;
final float EARTH_R = 30;
final float GAMMA   = 0.898;          // shadow axis offset in R(Earth)
final float UMBRA_K = 294.0 / 6371.0; // umbra width in R(Earth)

void settings() {
  size(W, H, P3D);
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
  pushMatrix();
  camera();
  ortho(0, width, height, 0);
  hint(DISABLE_DEPTH_TEST);
  noStroke();

  // background gradient (deep space, slightly lighter toward the Sun)
  for (int y = 0; y < H; y += 3) {
    float t = y / (float) H;
    fill(lerpColor(color(6, 10, 20), color(11, 17, 32), t));
    rect(0, y, W, 3);
  }

  drawStars();
  drawOrbitRings();
  drawShadowCones();
  drawSun();
  drawCorona();
  drawMoon();
  drawEarth();

  hint(ENABLE_DEPTH_TEST);
  popMatrix();
}

void drawStars() {
  blendMode(ADD);
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

void drawOrbitRings() {
  noFill();

  // Earth's orbit around the Sun
  stroke(96, 120, 190, 18);
  strokeWeight(1);
  ellipse(SX, SY, 560, 560);

  // Moon's orbit around Earth, tilted ~5 deg
  stroke(150, 170, 220, 22);
  ellipse(EX, EY, 150, 150 * cos(radians(5)));

  strokeWeight(1);
}

void drawShadowCones() {
  noStroke();

  // penumbra — soft wide veil from the Moon limb toward Earth
  beginShape(TRIANGLE_STRIP);
  fill(120, 140, 190, 6);
  for (int i = 0; i <= 36; i++) {
    float a = map(i, 0, 36, 0, TWO_PI);
    float ca = cos(a), sa = sin(a);
    vertex(SX + ca * MOON_R, SY + sa * MOON_R);
    vertex(EX + ca * (EARTH_R * 2.6), EY + sa * (EARTH_R * 2.6));
  }
  endShape();

  // umbra — narrow dark needle at the gamma-offset point
  beginShape(TRIANGLE_STRIP);
  fill(2, 3, 8, 55);
  float TX = EX + 6;
  float TY = EY + GAMMA * EARTH_R;
  float half = max(1.0, EARTH_R * UMBRA_K * 3);
  for (int i = 0; i <= 36; i++) {
    float a = map(i, 0, 36, 0, TWO_PI);
    float ca = cos(a), sa = sin(a);
    vertex(SX + ca * MOON_R, SY + sa * MOON_R);
    vertex(TX + ca * half, TY + sa * half);
  }
  endShape();
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

void drawEarth() {
  noStroke();
  fill(30, 64, 118);
  ellipse(EX, EY, EARTH_R * 2, EARTH_R * 2);
  // terminator — dark crescent away from the Sun
  fill(8, 14, 32, 150);
  ellipse(EX + EARTH_R * 0.42, EY + EARTH_R * 0.30, EARTH_R * 1.7, EARTH_R * 1.7);
  // atmosphere rim
  blendMode(ADD);
  noFill();
  stroke(150, 200, 255, 120);
  strokeWeight(2);
  arc(EX, EY, EARTH_R * 2.1, EARTH_R * 2.1, -1.2, 0.25);
  strokeWeight(1);
  blendMode(BLEND);

  // umbra spot at the gamma-offset point on the lit face
  noStroke();
  fill(2, 3, 8, 230);
  ellipse(EX + 6, EY + GAMMA * EARTH_R, EARTH_R * UMBRA_K * 6, EARTH_R * UMBRA_K * 6);
}

void drawHUD() {
  camera();
  ortho(0, width, height, 0);
  hint(DISABLE_DEPTH_TEST);

  if (hudFont != null) {
    textFont(hudFont);
  }
  textAlign(LEFT, TOP);
  fill(150, 175, 225, 185);

  text("SOLAR ECLIPSE // 12 AUG 2026 // TOTALITY 02m18s", 14, 14);
  text("GAMMA +0.898   MAG 1.0386   PATH 294 KM   SAROS 126", 14, 28);
  text("GREATEST 17:46 UTC   MOON ~1.032x SUN", 14, 42);

  hint(ENABLE_DEPTH_TEST);
}
