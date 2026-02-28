import gifAnimation.*; // from gifAnimation library
GifMaker gifExport;

int W = 1280;
int H = 720;
int totalFrames = 120;
int frameIndex = 0;
boolean recording = true;

public void settings(){
  size(W, H);
}

void setup() {
  frameRate(30);
  // Create GifMaker: filename, frameDelay (in centiseconds), repeat (0 = loop)
  gifExport = new GifMaker(this, "output_raw.gif");
  gifExport.setRepeat(0);
  //gifExport.frameRate(30); // affects timing if you use delay method
  // If using addFrame(), delay is set per frame via gifExport.setDelay(ms)
  gifExport.setDelay(33); // ~30 fps -> 33 ms per frame
  // Optionally reduce color depth early by enabling dither (gifAnimation does quantize automatically)
  background(30);
}

void draw() {
  // Example animation: moving gradient + ellipse
  noStroke();
  fill(30,15);
  rect(0,0,width,height);

  float x = map(frameIndex, 0, totalFrames-1, -W/2, W+W/2);
  stroke(255);
  line(x-height/2,0,x+height/2,height);

  // Add frame to GIF (captures the current canvas)
  if (recording) {
  // filter(POSTERIZE, 8);
    gifExport.addFrame();
    ++frameIndex;
    if (frameIndex >= totalFrames) {
      // finish writing file
      gifExport.finish();
      recording = false;
      println("Wrote output_raw.gif");
      noLoop();
      println("Optional: run gifsicle for further optimization:");
      println("gifsicle -O3 --colors 16 output_raw.gif -o output_optimized.gif");
    }
  }
}
