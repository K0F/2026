/*ded by Kof @
    eclipse of the year

                 .
        .        ;|         .
         .    .-; `-.        .
   .     .  .'  |  `.  .     .
         . /    )|(    \  .     .
   .     ;     |||     ;  .
          \    (o o)    /        .
   .      '-.  \_/  .-'    .
        .    `-.   .-'      .
   .          .  (.)  .   .         .
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

Solar Eclipse of August 12, 2026 — Prague View (86.25% Partial Eclipse)
*/

PFont hudFont;

final int W = 932;
final int H = 576;

final float SUN_R  = 160.0;
final float MOON_R = 165.12; // Preserves the exact ~1.032 apparent radius ratio

void settings() {
  size(W, H);
  smooth(8);
}

void setup() {
  try {
    hudFont = loadFont("TerminessNFP-12.vlw");
  } catch (Exception e) {
    hudFont = createFont("Monospaced", 12);
  }
  noiseSeed(17);
}

void draw() {
  drawBackground();
  drawSunAndMoonPartial();
  drawHUD();
  
  if (frameCount == 2) {
    save("eclipse_prague_2d.png");
    exit();
  }
}

void drawBackground() {
  // Full-canvas evening twilight gradient (horizon geometry removed)
  for (int y = 0; y < H; y++) {
    float t = y / (float) H;
    color topColor = color(8, 12, 24);
    color midColor = color(32, 22, 40);
    color lowColor = color(165, 75, 40);
    color c;
    if (t < 0.5) {
      c = lerpColor(topColor, midColor, t / 0.5);
    } else {
      c = lerpColor(midColor, lowColor, (t - 0.5) / 0.5);
    }
    stroke(c);
    line(0, y, W, y);
  }
}

void drawSunAndMoonPartial() {
  pushMatrix();
  translate(W / 2, H / 2);

  // Atmospheric solar glow
  blendMode(ADD);
  noStroke();
  for (int i = 0; i < 15; i++) {
    float rr = SUN_R * (1.08 + i * 0.10);
    float al = 25 * (1 - i / 15.0);
    fill(255, 170, 90, al);
    ellipse(0, 0, rr * 2, rr * 2);
  }
  blendMode(BLEND);

  // Solar disk body
  noStroke();
  for (int i = 0; i < 20; i++) {
    float rr = SUN_R * (1 - i / 20.0);
    float t = i / 20.0;
    fill(lerpColor(color(255, 252, 235), color(255, 145, 35), t));
    ellipse(0, 0, rr * 2, rr * 2);
  }

  // Moon position yielding 86.25% obscuration (Prague view at max eclipse)
  float moonOffsetX = 20.0;
  float moonOffsetY = 45.0;

  pushMatrix();
  translate(moonOffsetX, moonOffsetY);
  
  // Dark lunar body
  fill(10, 10, 16);
  ellipse(0, 0, MOON_R * 2, MOON_R * 2);
  
  // Atmospheric rim line along the overlapping lunar edge
  noFill();
  stroke(255, 190, 140, 110);
  strokeWeight(1.2);
  ellipse(0, 0, MOON_R * 2, MOON_R * 2);
  
  popMatrix();

  // Highlight at crescent tips
  blendMode(ADD);
  noStroke();
  fill(255, 90, 60, 150);
  ellipse(-SUN_R * 0.52, -SUN_R * 0.48, 14, 14);
  ellipse(SUN_R * 0.48, -SUN_R * 0.52, 12, 12);
  blendMode(BLEND);

  popMatrix();
}

void drawHUD() {
  pushStyle();
  
  // Translucent dark backing panel for high contrast & crisp text readability
  noStroke();
  fill(10, 14, 24, 215);
  rect(14, 14, 590, 130, 6);
  
  // Border outline
  stroke(80, 110, 160, 140);
  strokeWeight(1);
  noFill();
  rect(14, 14, 590, 130, 6);

  if (hudFont != null) {
    textFont(hudFont);
  } else {
    textSize(12);
  }
  
  textAlign(LEFT, TOP);
  
  int startX = 26;
  int startY = 24;
  int lineH  = 18;

  // Header line
  fill(255, 220, 130);
  text("SOLAR ECLIPSE // 12 AUG 2026 // PRAGUE VIEW (PARTIAL)", startX, startY);

  // Calculated astronomical data lines
  fill(210, 230, 255);
  text("OBSCURATION: 86.25%   |  MAX ECLIPSE: 20:11 CEST (18:11 UTC)", startX, startY + lineH);
  text("POSITION:    AZ 292° (WNW)  |  ALTITUDE: ~1.7° (SUNSET)", startX, startY + lineH * 2);
  text("ELEMENTS:    GAMMA +0.8977  |  MAGNITUDE 1.0386  |  SAROS 126", startX, startY + lineH * 3);
  text("ANGULAR:     SUN 15'47.0\"   |  MOON 16'16.9\" (RATIO 1.032)", startX, startY + lineH * 4);
  
  fill(140, 170, 210);
  text("UMBRA WIDTH: 294 KM         |  GREATEST POINT: 65.2°N 25.2°W", startX, startY + lineH * 5);

  popStyle();
}
