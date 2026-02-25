// Processing sketch: Fractal driven by value = e^PI - PI (~19.999099979189474)
// Reliable Mandelbrot-style render with coloring

int W = 800;
int H = 800;
float value = 19.999099979189474;
int maxIter = 500;
float bailout = 4.0; // squared radius threshold

void settings() {
  size(W, H);
  pixelDensity(displayDensity());
}

void setup() {
  colorMode(HSB, 1.0);
  noLoop();
}

void keyPressed(){
	if(key==' '){
		saveFrame("screenshot#####.png");
	}
}

void draw() {
  loadPixels();

  // Derive parameters from value
  float frac = value - floor(value);
  // Choose a center near the classic fractal area but offset by value for variety
  float cx = -0.7f + 0.02f * (value % 3.0f);
  float cy = 0.0f + 0.02f * (frac - 0.5f);

  // Zoom: moderate zoom so image is not all black or uniform
  float zoom = 3.0f / 2.5f; // view width in complex plane
  // Allow small additional zoom variation from value
  zoom *= pow(0.95f, (value % 10.0f));

  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      // Map pixel to complex plane
      float re = map(x, 0, W, cx - zoom, cx + zoom);
      float im = map(y, 0, H, cy - zoom * H / W, cy + zoom * H / W);

      // Mandelbrot iteration: z_{n+1} = z_n^2 + c  with z0 = 0, c = (re, im)
      float zx = 0;
      float zy = 0;
      int iter = 0;
      float mod2 = 0;

      for (int i = 0; i < maxIter; i++) {
        float zx2 = zx*zx - zy*zy + re;
        float zy2 = 2*zx*zy + im;
        zx = zx2;
        zy = zy2;
        mod2 = zx*zx + zy*zy;
        if (mod2 > bailout*bailout) { // escape
          iter = i;
          break;
        }
        iter = i;
      }

      // Smooth coloring
      float mu = iter;
      if (mod2 > 0 && iter < maxIter-1) {
        mu = iter + 1 - log(log(sqrt(mod2))) / log(2);
      }

      // Map mu to color using value-derived hue offset
      float hueOffset = (value % 1.0f); // fractional part gives subtle offset
      float hue = (hueOffset + 0.08f * mu / maxIter) % 1.0f;
      float sat = 0.85f;
      float bright;
      if (iter >= maxIter-1) {
        // likely in the set: dark but not pure black
        bright = 0.02f + 0.12f * (0.5f + 0.5f * sin(value));
        sat = 0.12f;
      } else {
        bright = pow(mu / maxIter, 0.45f);
      }

      pixels[x + y*W] = color(hue, sat, bright);
    }
  }

  updatePixels();
}
