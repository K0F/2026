#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include "processing.h"
#include "libraries/io.h"
#include "libraries/serial.h"
#include "libraries/net.h"
#include "libraries/osc.h"
#include "libraries/video.h"
#include "libraries/arduino.h"
#include "libraries/midi.h"
#include "libraries/geomerative.h"
#include "libraries/xml.h"
#include "libraries/minim.h"

typedef PdeRecorder Recorder;
#define Recorder_ctor PdeRecorder_ctor

extern int num;
extern bool grid;


#line 1 "sketch.pde"
int num = 36;
#line 2 "sketch.pde"
bool grid = false;
#line 4 "sketch.pde"
void setup(void){ 
#line 5 "sketch.pde"
size_converted(814 *2, 576 *2);
#line 6 "sketch.pde"
loadFont( "UniversLTStd-12.vlw");
#line 7 "sketch.pde"
} 
#line 9 "sketch.pde"
void draw(void){ 
#line 11 "sketch.pde"
background( 0);
#line 12 "sketch.pde"
stroke( 255, 255 / 3.0);
#line 14 "sketch.pde"
if( grid){ 
#line 15 "sketch.pde"
line( 0, 0, width, height);
#line 16 "sketch.pde"
line( width, 0, 0, height);
#line 17 "sketch.pde"
line( width / 2, 0, width / 2, height);
#line 18 "sketch.pde"
line( 0, height / 2, width, height / 2);
#line 19 "sketch.pde"
} 
#line 21 "sketch.pde"
for( int i = 0;
i < num;
i ++ ){ 
#line 22 "sketch.pde"
float angle = i / ( num + 0.0f) * TWO_PI;
#line 23 "sketch.pde"
pushMatrix();
#line 24 "sketch.pde"
translate( width / 2, height / 2);
#line 25 "sketch.pde"
rotate( angle);
#line 26 "sketch.pde"
line( 0, 0, width / 1.5, 0);
#line 27 "sketch.pde"
popMatrix();
#line 28 "sketch.pde"
} 
#line 30 "sketch.pde"
pushStyle();
#line 31 "sketch.pde"
noFill();
#line 33 "sketch.pde"
stroke( 0xFF00CCFF, 120);
#line 34 "sketch.pde"
strokeWeight( 5);
#line 35 "sketch.pde"
ellipse( width / 2, height / 2, 205, 205);
#line 36 "sketch.pde"
popStyle();
#line 39 "sketch.pde"
fill( 0, 255 / 4.0 * 3.0);
#line 40 "sketch.pde"
stroke( 127, 127, 250);
#line 42 "sketch.pde"
ellipse( width / 2, height / 2, 200, 200);
#line 44 "sketch.pde"
fill( 0xFF00CCFF);
#line 46 "sketch.pde"
text( "36dh dekans = 36 * 10° EarthR", 40, 50);
#line 48 "sketch.pde"
if( frameCount == 1) 
#line 49 "sketch.pde"
save( "dh36_paprsky.png");
#line 50 "sketch.pde"
}

int main(void) {
    setup();
    if (_windowInit == 0) size3(640, 480, "Processing Ray");
    while (!WindowShouldClose() && !_exitRequested) {
        beginDraw();
        if (_loopRunning || _redrawPending) {
            _redrawPending = false;
            draw();
        }
        endDraw();
    }
    destroyProcessing();
    CloseWindow();
    return 0;
}
