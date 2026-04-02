// kof26

void setup(){
	size(1920,1360);
}

void draw(){
	background(250);
	noStroke();
	for(int i = 0 ; i < 100; ++i){
		float hr = pow(i,2)/100.0+1;
		fill(i%2==0?5:255);

		ellipse(width/2,height/2,height/(3+hr)*2.0,height/(3+hr)*2.0);
	}

	if(frameCount==1)
	save("format.png");	
}
