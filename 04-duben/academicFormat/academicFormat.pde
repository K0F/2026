// kof26

void setup(){
	size(1920,1360);
}

void draw(){
	background(230);
	noStroke();
	float num = 12.0;
	for(int i = 0 ; i < num; ++i){
		float hr = pow(2.0,i/num+1.0)+1.0;
		fill(i%2==0?0:240);

		float R = height/hr;
		ellipse(width/2,height/2,R,R);
	}

	if(frameCount==1)
	save("format.png");	
}
