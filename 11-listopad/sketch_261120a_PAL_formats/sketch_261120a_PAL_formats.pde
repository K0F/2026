int num = 36;
boolean grid = false;

void setup() {
  size(814*2, 576*2);
  loadFont("UniversLTStd-12.vlw");
}

void draw() {

  background(0);
  stroke(255,255/3.0);

  if (grid) {
    line(0, 0, width, height);
    line(width, 0, 0, height);
    line(width/2, 0, width/2, height);
    line(0, height/2, width, height/2);
  }

  for (int i =0; i < num; i++) {
    float angle = i/(num+0.0f)*TWO_PI;
    pushMatrix();
    translate(width/2, height/2);
    rotate(angle);
    line(0, 0, width/1.5, 0);
    popMatrix();
  }

    pushStyle();
  noFill();
  
  stroke(#FFCC00,120);
  strokeWeight(5);
  ellipse(width/2,height/2,205,205);
  popStyle();

  
  fill(0,255/4.0*3.0);
  stroke(127,127,250);
  
  ellipse(width/2,height/2,200,200);
  
  fill(#ffcc00);
  
  text("36dh dekans = 36 * 10° EarthR",40,50);
  
  if(frameCount==1)
  save("dh36_paprsky.png");
}
