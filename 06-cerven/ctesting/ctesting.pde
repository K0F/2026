void setup(){
	size(932, 576);
}

void draw(){
	background(0);
  stroke(255);
  line(0,0,width,height);
  line(0,height,width,0);
  stroke(255,200,0);
  line(height,0,height,height);
  line(0,height/2,width/2,height/2);
}
