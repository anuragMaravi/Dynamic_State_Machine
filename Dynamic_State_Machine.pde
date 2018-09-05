int x = 1;

void setup() {
  size(1200, 720);
  frameRate(1);
}
void draw() {
  background(0);
  
  pushMatrix();
  translate(width*0.5, height*0.5);
  //rotate(frameCount / 200.0);
  
  polygon(0, 0, 200, x); // Shape
  x++;
  if(x>5){
    x = 1;
  }
  popMatrix();
  
}

void polygon(float x, float y, float radius, int npoints) {
  float angle = TWO_PI / npoints;
  int s = 1;
  beginShape();
  for (float a = 0; a < TWO_PI; a += angle) {    
    float sx = x - cos(a) * radius;
    float sy = y - sin(a) * radius;
    fill(255);    
    ellipse(sx, sy, 150, 150);
    textSize(32);
    fill(0);
    
    textAlign(CENTER, CENTER);
    text("State " + s, sx, sy);
    s++;
  }
  endShape(CLOSE);
}
