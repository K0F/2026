
int DETAIL = 20;

void setup(){
  size(1640,720);
  noiseSeed(26);
}


void draw(){
  background(3);
  int skip = 1;
  for(int detail = 0; detail < DETAIL; detail++){
  stroke(255,detail*3);
  for(int i = 0 ; i < width; i+=skip){
    float n1 = noise(radians(i*10.0)/20.0,detail);
    float x = map(i,0,width,0,width);
    float y = height/(detail+1.0);
    pushMatrix();
    translate(x,y);
    rotate(n1);
    line(0,-y,0,y);
    popMatrix();
  }
  }
  save("background.png");
  noLoop();
}
