import gifAnimation.*;

boolean record = false;
GifMaker gifExport;


void setup() {
  size(720, 576, P2D);

  PFont font = loadFont("UniversLTStd-Bold-16.vlw");
  textFont(font);

  if (record) {
    gifExport = new GifMaker(this, "export.gif");
    gifExport.setRepeat(0); // make it an "endless" animation
  }
}


void draw() {
  background(0);

  int cnt = 0 ;

  for (int i = 0; i < height; i++) {
    int h = i + (int)((noise(sin((i/19.0+0.0f)*TAU), cos(cnt++/199.0*TAU))-0.5f)*1000.0);
    double x =
      (sin(frameCount/60.0 + h + (h*0.0001f*noise(frameCount/1600.1+h/575.494, h/1000.1234+0.0f+frameCount/600.0)) * TAU)+1.0)/2.0 * width;
    float l = pow(noise(cnt/1000.0123, (float)x/999.0, cos(frameCount/1000.0+(cnt/10000.1)*TAU)*10.0 ), 4.0)*100.0;



    stroke(255, 127);
    pushMatrix();
    translate((float)x/2.0+width/4, h/2.0+height/3.0);
    rotate(atan2(height/2-h, width/2-(float)x));
    line((float)l*-1, 2, (float)l, 0);
    popMatrix();
  }



  fill(255,127);
  text("kof 26", width-120, height-18);
  
  
  if (record) {
    gifExport.setDelay(1);
    gifExport.addFrame();
    //saveFrame("/mnt/ssd/render/261112/fr#####.tga");
  }
}



void keyPressed() {
  gifExport.finish();
  println("gif saved");
}
