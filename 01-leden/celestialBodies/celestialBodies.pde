CelestialBody sun;
ArrayList<CelestialBody> planets;

void setup() {
  size(800, 800);
  sun = new CelestialBody(0, 0, 100, color(255, 255, 0), 1.989 * pow(10, 30)); // Sun
  planets = new ArrayList<CelestialBody>();
  
  // Add planet instances with current positions and velocities (example values)
  planets.add(new CelestialBody(147.1e9, 0, 20, color(0, 0, 255), 5.972 * pow(10, 24), new PVector(0, 29.78e3))); // Earth
  planets.add(new CelestialBody(227.9e9, 0, 15, color(255, 0, 0), 6.417 * pow(10, 23), new PVector(0, 24.077e3))); // Mars
}

void draw() {
  background(0);
  translate(width / 2, height / 2); // Center the simulation
  
  sun.display();

  for (CelestialBody planet : planets) {
    planet.update(sun);
    planet.display();
  }
}

class CelestialBody {
  PVector position;
  float radius;
  color bodyColor; // Variable for color
  float mass;
  PVector velocity;

  CelestialBody(float x, float y, float r, color c, float m, PVector v) {
    position = new PVector(x, y);
    radius = r;
    bodyColor = c;
    mass = m;
    velocity = v.copy(); // Initialize with given velocity
  }
  
  void update(CelestialBody sun) {
    PVector force = PVector.sub(sun.position, position);
    float distanceSq = constrain(force.magSq(), 100, 100000); // Avoid singularity
    float strength = (GravitationalConstant * sun.mass * mass) / distanceSq;
    force.setMag(strength);
    
    velocity.add(force.mult(1/mass)); // Update velocity based on force and mass
    position.add(velocity); // Update position based on velocity
  }
  
  void display() {
    fill(bodyColor); // Use body color
    noStroke();
    ellipse(position.x, position.y, radius, radius);
  }
}

final float GravitationalConstant = 6.67430 * pow(10, -11); // Gravitational constant
