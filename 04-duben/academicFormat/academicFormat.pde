// kof26

void setup(){
	size(1920,1360);
}

void draw(){
	background(230);
	noStroke();
	float num = 64.0;
	for(int i = 0 ; i < num; ++i){
		float hr = pow(2.0,i/num+1.0);
		fill(i%2==0?0:240);

		float R = width*pow(2,0.5)/hr/2.0;
		ellipse(width/2,height/2,R,R);
	}

  noFill();
  stroke(0,32);

  ellipse(width,height,height*2,height*2);
  ellipse(0,height,height*2,height*2);
  ellipse(0,0,height*2,height*2);
  ellipse(width,0,height*2,height*2);

  line(height,0,height,width);
  line(width-height,0,width-height,width);

	if(frameCount==1)
	save("format.png");
}

/*
void colorChecker(){
  
  colors = {color()};

}
*/
